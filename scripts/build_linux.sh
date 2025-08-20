#!/bin/bash

set -e

echo "Building Linux libraries..."

cd "$(dirname "$0")/../rust"

# Check if necessary build tools are available
if ! command -v gcc &> /dev/null; then
    echo "ERROR: gcc is not installed"
    echo "Install it with: sudo apt-get install build-essential"
    exit 1
fi

# Linux target
TARGET="x86_64-unknown-linux-gnu"

echo "Building for $TARGET..."
cargo build --target $TARGET --release

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build for $TARGET"
    exit 1
fi

# Copy library to Linux directory
mkdir -p ../linux
cp target/$TARGET/release/libflutter_rust_http.so ../linux/

echo "Linux build completed successfully!"
echo "Library is available at: ../linux/libflutter_rust_http.so"