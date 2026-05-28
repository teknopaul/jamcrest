PREFIX   ?= /usr/local
CXX      ?= g++
CXXFLAGS  = -std=c++17 -Wall -Wextra -Werror
LDFLAGS   =

SRC_CPP  = src/cpp/main.cpp src/cpp/v8_host.cpp src/cpp/cli_args.cpp
TARGET   = target/jamcrest

-include setup/.v8.mk

CXXFLAGS += $(V8_CFLAGS)
LDFLAGS  += $(V8_LDFLAGS)

.PHONY: all clean distclean setup test install

all: $(TARGET)

$(TARGET): $(SRC_CPP) | target
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

target:
	mkdir -p target

setup:
	bash setup/install-deps.sh

clean:
	rm -rf target

distclean: clean
	rm -rf setup/_deps setup/.v8.mk

test: all
	bash test/run-all.sh

install: all
	install -d $(PREFIX)/bin
	install -m 755 $(TARGET) $(PREFIX)/bin/
	install -d $(PREFIX)/share/jamcrest/js
	cp -r src/js/. $(PREFIX)/share/jamcrest/js/
