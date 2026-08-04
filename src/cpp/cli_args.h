#pragma once
#include <string>
#include <utility>
#include <vector>

struct CliArgs {
    std::string matcher_path;
    bool ignore_unknown = false;
    bool quiet          = false;
    bool help           = false;
    bool version        = false;
    std::vector<std::pair<std::string,std::string>> vars; // --var name=value (string)
    std::vector<std::string> args_exprs;                  // --args=EXPR (raw JS)
    std::string array_sort_keys;                          // --array-sort-keys=id,name (comma-separated)
    std::string template_path;  // --template <path>
    std::string data_path;      // --data <path>
    std::string error;  // non-empty → usage error

    static CliArgs parse(int argc, char* argv[]);
};
