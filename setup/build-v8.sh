#!/usr/bin/env bash
# Build V8 monolith from source using depot_tools (fallback when no system V8)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/_deps"
V8_MK="$SCRIPT_DIR/.v8.mk"
MONOLITH="$DEPS_DIR/v8/out/x64.release/obj/libv8_monolith.a"

if [ -f "$MONOLITH" ]; then
    echo "libv8_monolith.a already built, skipping."
    cat > "$V8_MK" <<EOF
V8_CFLAGS := -I$DEPS_DIR/v8/include
V8_LDFLAGS := $MONOLITH -lpthread -ldl
EOF
    exit 0
fi

mkdir -p "$DEPS_DIR"

# depot_tools
if [ ! -d "$DEPS_DIR/depot_tools" ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
        "$DEPS_DIR/depot_tools"
fi
export PATH="$DEPS_DIR/depot_tools:$PATH"

cd "$DEPS_DIR"
if [ ! -d v8 ]; then
    fetch v8
fi

cd v8
gclient sync

# Generate build files
gn gen out/x64.release --args='
    is_debug=false
    target_cpu="x64"
    v8_monolithic=true
    is_component_build=false
    v8_use_external_startup_data=false
    use_custom_libcxx=false
'

ninja -C out/x64.release v8_monolith

cat > "$V8_MK" <<EOF
V8_CFLAGS := -I$DEPS_DIR/v8/include
V8_LDFLAGS := $MONOLITH -lpthread -ldl
EOF
echo "V8 build complete. Wrote $V8_MK"
