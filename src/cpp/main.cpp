#include <cstdio>
#include <cstring>

#define JAMCREST_VERSION "0.1.0"

int main(int argc, char* argv[]) {
    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[i], "--version") == 0) {
            std::printf("jamcrest %s\n", JAMCREST_VERSION);
            return 0;
        }
        if (std::strcmp(argv[i], "--help") == 0) {
            std::printf("Usage: jamcrest [--matcher <path>] [--version] [--help]\n");
            return 0;
        }
    }
    std::printf("jamcrest\n");
    return 0;
}
