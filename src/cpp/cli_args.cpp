#include "cli_args.h"
#include <cstring>

CliArgs CliArgs::parse(int argc, char* argv[]) {
    CliArgs a;
    for (int i = 1; i < argc; i++) {
        const char* arg = argv[i];
        if (std::strcmp(arg, "--help") == 0) {
            a.help = true;
        } else if (std::strcmp(arg, "--version") == 0) {
            a.version = true;
        } else if (std::strcmp(arg, "--ignore-unknown") == 0 ||
                   std::strcmp(arg, "--ignore-properties") == 0) {
            a.ignore_unknown = true;
        } else if (std::strcmp(arg, "--quiet") == 0) {
            a.quiet = true;
        } else if (std::strcmp(arg, "--matcher") == 0) {
            if (i + 1 >= argc) {
                a.error = "--matcher requires a path argument";
                return a;
            }
            a.matcher_path = argv[++i];
        } else {
            a.error = std::string("unknown flag: ") + arg;
            return a;
        }
    }
    return a;
}
