#include <cstdio>
#include <cstring>
#include <climits>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <unistd.h>
#include "v8_host.h"
#include "cli_args.h"

#define JAMCREST_VERSION "0.1.0"

static std::string locate_js_dir(const char* argv0) {
    const char* env = std::getenv("JAMCREST_JS_DIR");
    if (env && *env) return env;

    char resolved[PATH_MAX];
    if (realpath(argv0, resolved)) {
        std::string bin(resolved);
        auto slash = bin.rfind('/');
        if (slash != std::string::npos) {
            std::string share = bin.substr(0, slash) + "/../share/jamcrest/js";
            if (access((share + "/jamcrest-impl.js").c_str(), R_OK) == 0)
                return share;
        }
    }
    return "./src/js";
}

static bool read_stdin(std::string& out, std::string& err) {
    std::ostringstream buf;
    buf << std::cin.rdbuf();
    if (std::cin.bad()) { err = "error reading stdin"; return false; }
    out = buf.str();
    if (out.size() > 64 * 1024 * 1024) { err = "stdin exceeds 64 MB limit"; return false; }
    return true;
}

static bool read_file(const std::string& path, std::string& out, std::string& err) {
    std::ifstream f(path);
    if (!f.is_open()) { err = "cannot open: " + path; return false; }
    std::ostringstream buf;
    buf << f.rdbuf();
    out = buf.str();
    return true;
}

// Produce a JS string literal (double-quoted) for embedding in source.
static std::string js_string_literal(const std::string& s) {
    std::string out = "\"";
    for (unsigned char c : s) {
        if      (c == '\\') out += "\\\\";
        else if (c == '"')  out += "\\\"";
        else if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else if (c == '\0') out += "\\u0000";
        else                out += static_cast<char>(c);
    }
    return out + "\"";
}

// Strip one level of JSON string quotes from a JS string result like "\"foo\""
static std::string unquote_json_string(const std::string& s) {
    if (s.size() >= 2 && s.front() == '"' && s.back() == '"')
        return s.substr(1, s.size() - 2);
    return s;
}

int main(int argc, char* argv[]) {
    CliArgs args = CliArgs::parse(argc, argv);

    if (!args.error.empty()) {
        std::fprintf(stderr, "jamcrest: %s\n", args.error.c_str());
        std::fprintf(stderr, "Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]\n");
        return 2;
    }
    if (args.version) { std::printf("jamcrest %s\n", JAMCREST_VERSION); return 0; }
    if (args.help) {
        std::printf("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]\n");
        std::printf("       Reads JSON from stdin, matches against matcher JS file.\n");
        std::printf("       Exit: 0=match  1=no-match  2=error\n");
        return 0;
    }
    if (args.matcher_path.empty()) {
        std::fprintf(stderr, "jamcrest: --matcher is required\n");
        std::fprintf(stderr, "Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]\n");
        return 2;
    }

    std::string err;
    std::string input_json;
    if (!read_stdin(input_json, err)) { std::fprintf(stderr, "jamcrest: %s\n", err.c_str()); return 2; }
    if (input_json.empty())           { std::fprintf(stderr, "jamcrest: empty input on stdin\n"); return 2; }

    std::string matcher_src;
    if (!read_file(args.matcher_path, matcher_src, err)) { std::fprintf(stderr, "jamcrest: %s\n", err.c_str()); return 2; }

    V8Host host;
    if (!host.Init(locate_js_dir(argv[0]))) { std::fprintf(stderr, "jamcrest: failed to initialize V8\n"); return 2; }

    for (const char* f : {"jamcrest-matchers.js", "jamcrest-impl.js", "jamcrest-bootstrap.js"}) {
        if (!host.LoadFile(f, err)) { std::fprintf(stderr, "jamcrest: %s\n", err.c_str()); return 2; }
    }

    // Validate JSON input
    std::string validate_src =
        "(function(){ try { return JSON.parse(" + js_string_literal(input_json) + "); }"
        "catch(e){ throw new Error('invalid JSON: ' + e.message); } })()";
    std::string parsed_input;
    if (!host.EvalReturn(validate_src, "<stdin>", parsed_input, err)) {
        std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
        return 2;
    }

    // Load matcher
    std::string matcher_eval = "globalThis.__matcher = (" + matcher_src + ");";
    if (!host.Eval(matcher_eval, args.matcher_path, err)) {
        std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
        return 2;
    }

    // Build opts
    std::string opts_json =
        std::string("{\"ignoreUnknown\":") + (args.ignore_unknown ? "true" : "false") + "}";

    // Run compare — parsed_input is already a JSON value; use it directly.
    std::string compare_expr =
        "jamcrest.compare(" + parsed_input + ", globalThis.__matcher, " + opts_json + ")";
    std::string result_json;
    if (!host.EvalReturn(compare_expr, "<compare>", result_json, err)) {
        std::fprintf(stderr, "jamcrest: runtime error: %s\n", err.c_str());
        return 2;
    }

    // Extract result.match
    std::string matched_expr = "(" + result_json + ").match";
    std::string matched_str;
    if (!host.EvalReturn(matched_expr, "<result>", matched_str, err)) {
        std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
        return 2;
    }
    bool matched = (matched_str == "true");

    if (!matched && !args.quiet) {
        std::string diag_expr = "(" + result_json + ").diagnostic || ''";
        std::string diag;
        if (host.EvalReturn(diag_expr, "<diag>", diag, err))
            diag = unquote_json_string(diag);
        if (!diag.empty())
            std::fprintf(stderr, "%s\n", diag.c_str());
    }

    return matched ? 0 : 1;
}
