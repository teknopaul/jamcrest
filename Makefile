PREFIX   ?= /usr/local
CXX      ?= g++
CXXFLAGS  = -std=c++17 -Wall -Wextra -Werror
LDFLAGS   =

SRC_CPP      = src/cpp/main.cpp src/cpp/v8_host.cpp src/cpp/cli_args.cpp
TARGET       = target/jamcrest
EMBEDDED_JS  = src/cpp/embedded_js.h

-include setup/.v8.mk

CXXFLAGS += $(V8_CFLAGS)
LDFLAGS  += $(V8_LDFLAGS)

.PHONY: all clean distclean setup test install

all: $(TARGET)

$(TARGET): $(SRC_CPP) $(EMBEDDED_JS) | target
	$(CXX) $(CXXFLAGS) -o $@ $(SRC_CPP) $(LDFLAGS)

$(EMBEDDED_JS): src/js/jamcrest-matchers.js src/js/jamcrest-impl.js src/js/jamcrest-bootstrap.js
	@echo '// Auto-generated from src/js/ — do not edit' > $@
	@echo '#pragma once' >> $@
	@echo '#include <cstddef>' >> $@
	xxd -i src/js/jamcrest-matchers.js  >> $@
	xxd -i src/js/jamcrest-impl.js      >> $@
	xxd -i src/js/jamcrest-bootstrap.js >> $@

target:
	mkdir -p target

setup:
	bash setup/install-deps.sh

clean:
	rm -rf target $(EMBEDDED_JS)

distclean: clean
	rm -rf setup/_deps setup/.v8.mk

test: all
	bash test/run-all.sh

install: all
	install -d $(PREFIX)/bin
	install -m 755 $(TARGET) $(PREFIX)/bin/
