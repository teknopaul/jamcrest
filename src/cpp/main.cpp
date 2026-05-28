#include <cstdio>
#include <cstring>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include "v8_host.h"
#include "cli_args.h"
#include "embedded_js.h"

#define JAMCREST_VERSION "0.1.0"

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

// Decode a JSON string literal ("...") into the actual string value.
static std::string unescape_json_string(const std::string& s) {
    if (s.size() < 2 || s.front() != '"' || s.back() != '"') return s;
    std::string out;
    out.reserve(s.size());
    for (size_t i = 1; i < s.size() - 1; ) {
        if (s[i] != '\\') { out += s[i++]; continue; }
        if (++i >= s.size() - 1) break;
        switch (s[i]) {
            case '"':  out += '"';  break;
            case '\\': out += '\\'; break;
            case '/':  out += '/';  break;
            case 'n':  out += '\n'; break;
            case 'r':  out += '\r'; break;
            case 't':  out += '\t'; break;
            case 'b':  out += '\b'; break;
            case 'f':  out += '\f'; break;
            case 'u': {
                if (i + 4 < s.size() - 1) {
                    unsigned int cp = 0;
                    for (int k = 1; k <= 4; k++) {
                        char c = s[i + k];
                        cp = cp * 16 + (c >= '0' && c <= '9' ? unsigned(c - '0') :
                                        c >= 'a' && c <= 'f' ? unsigned(c - 'a' + 10) :
                                        c >= 'A' && c <= 'F' ? unsigned(c - 'A' + 10) : 0u);
                    }
                    if      (cp < 0x80)  { out += char(cp); }
                    else if (cp < 0x800) { out += char(0xC0 | cp >> 6); out += char(0x80 | (cp & 0x3F)); }
                    else                 { out += char(0xE0 | cp >> 12);
                                           out += char(0x80 | ((cp >> 6) & 0x3F));
                                           out += char(0x80 | (cp & 0x3F)); }
                    i += 4;
                }
                break;
            }
            default: out += s[i]; break;
        }
        i++;
    }
    return out;
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
    if (!host.Init()) { std::fprintf(stderr, "jamcrest: failed to initialize V8\n"); return 2; }

    // Load embedded JS (compiled into binary via xxd -i)
    struct { const unsigned char* data; unsigned int len; const char* name; } js[] = {
        { src_js_jamcrest_matchers_js,  src_js_jamcrest_matchers_js_len,  "jamcrest-matchers.js"  },
        { src_js_jamcrest_impl_js,      src_js_jamcrest_impl_js_len,      "jamcrest-impl.js"      },
        { src_js_jamcrest_bootstrap_js, src_js_jamcrest_bootstrap_js_len, "jamcrest-bootstrap.js" },
    };
    for (auto& f : js) {
        std::string src(reinterpret_cast<const char*>(f.data), f.len);
        if (!host.Eval(src, f.name, err)) { std::fprintf(stderr, "jamcrest: %s\n", err.c_str()); return 2; }
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

    std::string opts_json =
        std::string("{\"ignoreUnknown\":") + (args.ignore_unknown ? "true" : "false") + "}";

    std::string compare_expr =
        "jamcrest.compare(" + parsed_input + ", globalThis.__matcher, " + opts_json + ")";
    std::string result_json;
    if (!host.EvalReturn(compare_expr, "<compare>", result_json, err)) {
        std::fprintf(stderr, "jamcrest: runtime error: %s\n", err.c_str());
        return 2;
    }

    std::string matched_str;
    if (!host.EvalReturn("(" + result_json + ").match", "<result>", matched_str, err)) {
        std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
        return 2;
    }
    bool matched = (matched_str == "true");

    if (!matched && !args.quiet) {
        std::string diag;
        if (host.EvalReturn("(" + result_json + ").diagnostic || ''", "<diag>", diag, err))
            diag = unescape_json_string(diag);
        if (!diag.empty())
            std::fprintf(stderr, "%s\n", diag.c_str());
    }

    return matched ? 0 : 1;
}
