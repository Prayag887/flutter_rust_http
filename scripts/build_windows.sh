#!/bin/bash

set -e

echo "Building Windows libraries..."

cd "$(dirname "$0")/../rust"

# Check if we're on Windows or using a cross-compilation environment
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Native Windows build
    TARGET="x86_64-pc-windows-msvc"


    echo "Building for $TARGET..."
    cargo build --target $TARGET --release

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to build for $TARGET"
        exit 1
    fi

    # Copy library to Windows directory
    mkdir -p ../windows
    cp target/$TARGET/release/flutter_rust_http.dll ../windows/
else
    # Cross-compilation from Linux/macOS
    echo "ERROR: Windows cross-compilation is not supported by this script"
    echo "Please run this script on a Windows system or set up proper cross-compilation"
    exit 1
fi

echo "Windows build completed successfully!"
echo "Library is available at: ../windows/flutter_rust_http.dll"