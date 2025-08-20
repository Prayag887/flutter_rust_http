#!/bin/bash

# Exit on error, unset variable, or pipe failure
set -euo pipefail

# Print errors with line number and command
trap 'echo "ERROR on line $LINENO: $BASH_COMMAND" >&2' ERR

echo "Building Android libraries..."

cd "$(dirname "$0")/../rust" || { echo "ERROR: native directory not found"; exit 1; }

# Auto-detect latest Android NDK if ANDROID_NDK_HOME is not set
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    if [ -n "${ANDROID_NDK:-}" ]; then
        export ANDROID_NDK_HOME="$ANDROID_NDK"
    elif [ -n "${ANDROID_SDK_ROOT:-}" ]; then
        # Pick latest NDK folder
        LATEST_NDK=$(ls -d "$ANDROID_SDK_ROOT/ndk/"* | sort -V | tail -n 1)
        if [ -z "$LATEST_NDK" ]; then
            echo "ERROR: No NDK found in \$ANDROID_SDK_ROOT/ndk"
            exit 1
        fi
        export ANDROID_NDK_HOME="$LATEST_NDK"
        echo "Using latest NDK at: $ANDROID_NDK_HOME"
    else
        echo "ERROR: ANDROID_NDK_HOME environment variable must be set"
        echo "Please set it to your Android NDK path"
        exit 1
    fi
fi

# Check if cargo-ndk is installed
if ! command -v cargo-ndk &> /dev/null; then
    echo "ERROR: cargo-ndk is not installed"
    echo "Install it with: cargo install cargo-ndk"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p ../android/src/main/jniLibs

# Android targets
TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "i686-linux-android" "x86_64-linux-android")

for target in "${TARGETS[@]}"; do
    echo "--------------------------------------------"
    echo "Building Rust library for $target..."
    echo "--------------------------------------------"

    # Build with cargo-ndk, using release mode
    if ! cargo ndk -t "$target" -o ../android/src/main/jniLibs build --release; then
        echo "ERROR: Failed to build for $target"
        exit 1
    fi
done

echo "============================================"
echo "Android build completed successfully!"
echo "Libraries are available at: ../android/src/main/jniLibs"
echo "============================================"
