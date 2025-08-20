#!/bin/bash

set -e

echo "Building macOS libraries..."

cd "$(dirname "$0")/../rust"

# Check if Xcode is available
if ! xcode-select -p &> /dev/null; then
    echo "ERROR: Xcode is not installed or not configured"
    exit 1
fi

# macOS targets
TARGETS=("x86_64-apple-darwin" "aarch64-apple-darwin")

for target in "${TARGETS[@]}"; do
    echo "Building for $target..."
    cargo build --target $target --release

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to build for $target"
        exit 1
    fi
done

# Check if lipo is available
if ! command -v lipo &> /dev/null; then
    echo "ERROR: lipo is not available"
    exit 1
fi

# Create universal binary
echo "Creating universal binary..."
lipo -create \
    target/x86_64-apple-darwin/release/libflutter_rust_http.dylib \
    target/aarch64-apple-darwin/release/libflutter_rust_http.dylib \
    -output ../macos/libflutter_rust_http.dylib

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create universal binary"
    exit 1
fi

echo "macOS build completed successfully!"
echo "Universal binary is available at: ../macos/libflutter_rust_http.dylib"