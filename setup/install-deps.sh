#!/usr/bin/env bash
# Detect and install V8 dependencies, then emit setup/.v8.mk
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V8_MK="$SCRIPT_DIR/.v8.mk"

emit_v8_mk() {
    local cflags="$1" ldflags="$2"
    cat > "$V8_MK" <<EOF
V8_CFLAGS := $cflags
V8_LDFLAGS := $ldflags
EOF
    echo "Wrote $V8_MK"
}

# Already configured
if [ -f "$V8_MK" ]; then
    echo "setup/.v8.mk already exists, skipping detection."
    exit 0
fi

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then echo apt
    elif command -v dnf &>/dev/null; then echo dnf
    elif command -v yum &>/dev/null; then echo yum
    elif command -v brew &>/dev/null; then echo brew
    else echo none
    fi
}

install_base_deps() {
    local pm="$1"
    case "$pm" in
        apt)
            sudo apt-get install -y build-essential pkg-config python3 curl git ;;
        dnf|yum)
            sudo "$pm" install -y gcc-c++ make pkg-config python3 curl git ;;
        brew)
            brew install pkg-config python3 curl git || true ;;
    esac
}

try_libnode_dev() {
    # Check if libnode-dev headers and libnode are present
    local inc=""
    if [ -d /usr/include/nodejs/deps/v8/include ]; then
        inc=/usr/include/nodejs/deps/v8/include
    elif [ -d /usr/include/node ]; then
        inc=/usr/include/node
    else
        return 1
    fi
    # Need libnode.so or libv8.so
    local lib=""
    if [ -f /usr/lib/x86_64-linux-gnu/libv8.so ]; then
        lib="-lv8 -lv8_libplatform"
    elif [ -f /usr/lib/x86_64-linux-gnu/libnode.so ] || \
         [ -f /usr/lib/aarch64-linux-gnu/libnode.so ]; then
        lib="-lnode"
    else
        return 1
    fi
    emit_v8_mk "-I$inc" "$lib"
}

PM=$(detect_pkg_manager)

if [ "$PM" != none ]; then
    echo "Installing base build dependencies via $PM..."
    install_base_deps "$PM"
fi

echo "Trying distro V8 (libnode-dev)..."
if [ "$PM" = apt ] && ! dpkg -l libnode-dev &>/dev/null 2>&1; then
    sudo apt-get install -y libnode-dev 2>/dev/null || true
fi

if try_libnode_dev; then
    echo "Using system V8 (via libnode-dev)."
    exit 0
fi

echo "No system V8 found, falling back to building from source..."
exec "$SCRIPT_DIR/build-v8.sh"
