#include <cstdio>
#include <cstring>
#include <climits>
#include <string>
#include <iostream>
#include <unistd.h>
#include <libgen.h>
#include "v8_host.h"

#define JAMCREST_VERSION "0.1.0"

static std::string locate_js_dir(const char* argv0) {
    // 1. Environment override
    const char* env = std::getenv("JAMCREST_JS_DIR");
    if (env && *env) return env;

    // 2. <binary>/../share/jamcrest/js  (installed path)
    char resolved[PATH_MAX];
    if (realpath(argv0, resolved)) {
        std::string bin(resolved);
        auto slash = bin.rfind('/');
        if (slash != std::string::npos) {
            std::string parent = bin.substr(0, slash); // bin dir
            std::string share = parent + "/../share/jamcrest/js";
            if (access((share + "/jamcrest-impl.js").c_str(), R_OK) == 0)
                return share;
        }
    }

    // 3. ./src/js relative to CWD (development)
    return "./src/js";
}

int main(int argc, char* argv[]) {
    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[i], "--version") == 0) {
            std::printf("jamcrest %s\n", JAMCREST_VERSION);
            return 0;
        }
        if (std::strcmp(argv[i], "--help") == 0) {
            std::printf("Usage: jamcrest --matcher <path> [--ignore-unknown] [--quiet]\n");
            std::printf("       Reads JSON from stdin, matches against matcher JS file.\n");
            std::printf("       Exit 0=match, 1=no match, 2=error.\n");
            return 0;
        }
    }

    std::string js_dir = locate_js_dir(argv[0]);

    V8Host host;
    std::string err;
    if (!host.Init(js_dir)) {
        std::fprintf(stderr, "jamcrest: failed to initialize V8\n");
        return 2;
    }

    // Load JS files
    for (const char* f : {"jamcrest-matchers.js", "jamcrest-impl.js", "jamcrest-bootstrap.js"}) {
        if (!host.LoadFile(f, err)) {
            std::fprintf(stderr, "jamcrest: %s\n", err.c_str());
            return 2;
        }
    }

    // Call bootstrap()
    std::string result;
    if (!host.Call("bootstrap", "", result, err)) {
        std::fprintf(stderr, "jamcrest: bootstrap failed: %s\n", err.c_str());
        return 2;
    }

    // Strip surrounding quotes from JSON string result
    if (result.size() >= 2 && result.front() == '"' && result.back() == '"')
        result = result.substr(1, result.size() - 2);

    std::printf("%s\n", result.c_str());
    return 0;
}
