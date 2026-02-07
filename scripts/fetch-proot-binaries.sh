#!/bin/bash
# Fetch pre-compiled PRoot binaries for Android
# Places them in jniLibs/<abi>/lib*.so so Android auto-extracts
# them to nativeLibraryDir with execute permission (bypasses W^X).
#
# Source: https://github.com/green-green-avk/build-proot-android
# These builds have libtalloc statically linked and include --link2symlink support.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JNILIBS_DIR="$SCRIPT_DIR/../flutter_app/android/app/src/main/jniLibs"
TMP_DIR=$(mktemp -d)

trap 'rm -rf "$TMP_DIR"' EXIT

BASE_URL="https://raw.githubusercontent.com/green-green-avk/build-proot-android/master/packages"

fetch_proot() {
    local jni_abi="$1"
    local tar_name="$2"
    local out_dir="$JNILIBS_DIR/$jni_abi"

    mkdir -p "$out_dir"
    echo "  [$jni_abi] Downloading $tar_name..."

    local tar_file="$TMP_DIR/$tar_name"
    if ! curl -fsSL "$BASE_URL/$tar_name" -o "$tar_file" 2>/dev/null; then
        echo "  [$jni_abi] FAILED: Could not download $tar_name"
        return 1
    fi

    local extract_dir="$TMP_DIR/extract-$jni_abi"
    mkdir -p "$extract_dir"
    tar xzf "$tar_file" -C "$extract_dir"

    # Copy proot binary
    local proot_bin
    proot_bin=$(find "$extract_dir" -name "proot" -not -name "proot-userland" -type f | head -1)
    if [ -z "$proot_bin" ]; then
        echo "  [$jni_abi] ERROR: proot binary not found in archive"
        return 1
    fi
    cp "$proot_bin" "$out_dir/libproot.so"
    chmod 755 "$out_dir/libproot.so"

    # Copy loader (64-bit)
    local loader
    loader=$(find "$extract_dir" -name "loader" -not -name "loader32" -type f | head -1)
    if [ -n "$loader" ]; then
        cp "$loader" "$out_dir/libprootloader.so"
        chmod 755 "$out_dir/libprootloader.so"
    fi

    # Copy loader32
    local loader32
    loader32=$(find "$extract_dir" -name "loader32" -type f | head -1)
    if [ -n "$loader32" ]; then
        cp "$loader32" "$out_dir/libprootloader32.so"
        chmod 755 "$out_dir/libprootloader32.so"
    fi

    echo "  [$jni_abi] OK — proot $(du -h "$out_dir/libproot.so" | cut -f1)"
}

echo "=== Fetching PRoot binaries for Android ==="
echo ""

SUCCESS=0
FAILED=0

for entry in "arm64-v8a:proot-android-aarch64.tar.gz" "armeabi-v7a:proot-android-armv7a.tar.gz" "x86_64:proot-android-x86_64.tar.gz"; do
    IFS=':' read -r abi tar_name <<< "$entry"
    echo "[$abi]"

    if fetch_proot "$abi" "$tar_name"; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "=== Summary ==="
echo "Success: $SUCCESS / 3"
if [ "$FAILED" -gt 0 ]; then
    echo "Failed: $FAILED"
    echo ""
    echo "Missing architectures will not be supported."
fi

echo ""
echo "Files:"
ls -la "$JNILIBS_DIR"/*/lib*.so 2>/dev/null || echo "  (none)"
