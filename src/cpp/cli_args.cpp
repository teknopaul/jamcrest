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
        } else if (std::strcmp(arg, "--var") == 0) {
            if (i + 1 >= argc) {
                a.error = "--var requires a name=value argument";
                return a;
            }
            std::string nv = argv[++i];
            auto eq = nv.find('=');
            if (eq == std::string::npos) {
                a.error = "--var value must be in name=value format";
                return a;
            }
            a.vars.push_back({nv.substr(0, eq), nv.substr(eq + 1)});
        } else if (std::strncmp(arg, "--args=", 7) == 0) {
            a.args_exprs.push_back(arg + 7);
        } else if (std::strcmp(arg, "--args") == 0) {
            if (i + 1 >= argc) {
                a.error = "--args requires a JS object expression";
                return a;
            }
            a.args_exprs.push_back(argv[++i]);
        } else if (std::strncmp(arg, "--array-sort-keys=", 18) == 0) {
            a.array_sort_keys = arg + 18;
        } else if (std::strcmp(arg, "--array-sort-keys") == 0) {
            if (i + 1 >= argc) {
                a.error = "--array-sort-keys requires a comma-separated list of field names";
                return a;
            }
            a.array_sort_keys = argv[++i];
        } else if (std::strcmp(arg, "--template") == 0) {
            if (i + 1 >= argc) { a.error = "--template requires a path"; return a; }
            a.template_path = argv[++i];
        } else if (std::strcmp(arg, "--data") == 0) {
            if (i + 1 >= argc) { a.error = "--data requires a path"; return a; }
            a.data_path = argv[++i];
        } else {
            a.error = std::string("unknown flag: ") + arg;
            return a;
        }
    }
    // --template and --matcher are mutually exclusive
    if (!a.template_path.empty() && !a.matcher_path.empty())
        a.error = "--template and --matcher are mutually exclusive";
    // --template requires --data and vice versa
    if (a.template_path.empty() != a.data_path.empty())
        a.error = "--template and --data must be used together";
    return a;
}
