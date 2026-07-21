#!/usr/bin/env bash
# Build the on-device Himark engine: `<root>/rust` as a C-ABI shared library.
#
# Two outputs, both gitignored and both generated -- F-Droid builds from source
# and rejects prebuilt binaries, so these must never be committed:
#
#   android/app/src/main/jniLibs/<abi>/libhejmark.so   what the APK ships
#   <root>/rust/target/release/libhejmark.so           what a desktop run loads
#
# Re-run this whenever `rust/src/ffi.rs` changes shape. The Dart side binds every
# C entry point up front (`lib/models/native_engine.dart`), so a library missing
# a symbol fails *every* call, not only the new one -- which is loud, and meant
# to be, but only helps if this gets run.
#
# The ABI list must match `abiFilters` in `android/app/build.gradle.kts`: that
# list also decides which ABIs get a Python interpreter, and an ABI with a
# compiler and no engine (or the reverse) is worse than one with neither.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gui=$(dirname "$here")
root=$(dirname "$gui")

abis=(armeabi-v7a arm64-v8a x86_64)

# `--host-only` skips the cross-compile, for a desktop run that needs no APK and
# no NDK -- which is what `flutter test` and `flutter run -d linux` actually use.
host_only=false
for arg in "$@"; do
    case "$arg" in
    --host-only) host_only=true ;;
    *)
        echo "usage: build_engine.sh [--host-only]" >&2
        exit 2
        ;;
    esac
done

if [ "$host_only" = true ]; then
    echo "building the desktop engine only"
    (cd "$root/rust" && cargo build --release)
    exit 0
fi

if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo "cargo-ndk is not installed: cargo install cargo-ndk" >&2
    echo "and add the targets: rustup target add \\" >&2
    echo "    armv7-linux-androideabi aarch64-linux-android x86_64-linux-android" >&2
    exit 1
fi

targets=()
for abi in "${abis[@]}"; do
    targets+=(-t "$abi")
done

echo "building the Android engine for ${abis[*]}"
(cd "$root/rust" && cargo ndk "${targets[@]}" \
    -o "$gui/android/app/src/main/jniLibs" build --release)

# The desktop library, which `flutter run -d linux` and `flutter test` load
# through the same NativeEngine by falling back to rust/target/.
echo "building the desktop engine"
(cd "$root/rust" && cargo build --release)
