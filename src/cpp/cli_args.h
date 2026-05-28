#pragma once
#include <string>

struct CliArgs {
    std::string matcher_path;
    bool ignore_unknown = false;
    bool quiet          = false;
    bool help           = false;
    bool version        = false;
    std::string error;  // non-empty → usage error

    static CliArgs parse(int argc, char* argv[]);
};
