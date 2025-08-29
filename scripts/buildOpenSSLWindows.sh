#!/bin/bash
# Build OpenSSL 3.5.2 for Android using NDK r27 on Windows

# User config - Update the OPENSSL_SRC path to point to complete source
export ANDROID_NDK_ROOT="/c/Users/user/AppData/Local/Android/Sdk/ndk/27.0.12077973"
export OPENSSL_SRC="/c/Users/user/Downloads/openssl-3.5.2/openssl-3.5.2"  # Update this path
export OPENSSL_OUT="/c/openssl-build"

# Add NDK toolchain to PATH
TOOLCHAIN_PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64/bin"
export PATH="$TOOLCHAIN_PATH:$PATH"

# Use Strawberry Perl
STRAWBERRY_PERL="/c/Strawberry/perl/bin/perl.exe"
if [ -f "$STRAWBERRY_PERL" ]; then
    PERL_CMD="$STRAWBERRY_PERL"
    echo "Using Strawberry Perl: $STRAWBERRY_PERL"
else
    PERL_CMD="perl"
    echo "Using system perl"
fi

# Check if perl works
if ! "$PERL_CMD" -v &> /dev/null; then
    echo "ERROR: Perl is not working properly"
    exit 1
fi

echo "Building OpenSSL 3.5.2 for Android..."
echo "OpenSSL Source: $OPENSSL_SRC"
echo "NDK Root: $ANDROID_NDK_ROOT"
echo "Output: $OPENSSL_OUT"
echo ""

# First, let's check what we actually have
echo "=== Checking OpenSSL Source ==="
if [ ! -d "$OPENSSL_SRC" ]; then
    echo "ERROR: OpenSSL source directory not found: $OPENSSL_SRC"
    echo "Please update OPENSSL_SRC path in the script"
    exit 1
fi

echo "OpenSSL source directory exists: $OPENSSL_SRC"

# Check for Configure script
if [ ! -f "$OPENSSL_SRC/Configure" ]; then
    echo "ERROR: Configure script not found in $OPENSSL_SRC"
    exit 1
fi
echo "✓ Configure script found"

# Check for Perl modules
if [ -d "$OPENSSL_SRC/util/perl/OpenSSL" ]; then
    echo "✓ OpenSSL Perl modules found"
    echo "Available modules:"
    ls "$OPENSSL_SRC/util/perl/OpenSSL/"
else
    echo "❌ OpenSSL Perl modules NOT found in $OPENSSL_SRC/util/perl/OpenSSL"
    echo "You need to download the complete OpenSSL source from:"
    echo "https://www.openssl.org/source/openssl-3.5.2.tar.gz"
    echo ""
    echo "Current contents of util directory:"
    if [ -d "$OPENSSL_SRC/util" ]; then
        ls -la "$OPENSSL_SRC/util/"
    else
        echo "util directory doesn't exist!"
    fi
    exit 1
fi

# Function to build OpenSSL
build_openssl() {
    local arch="$1"
    local target="$2"
    local api="$3"
    local cc="$4"
    
    echo ""
    echo "=== Building OpenSSL for $arch ==="
    
    local outdir="$OPENSSL_OUT/$arch"
    rm -rf "$outdir"
    mkdir -p "$outdir"
    
    cd "$OPENSSL_SRC" || return 1
    
    # Clean previous files
    rm -f Makefile configdata.pm
    
    # Set environment variables
    export CC="$TOOLCHAIN_PATH/${cc}.cmd"
    export AR="$TOOLCHAIN_PATH/llvm-ar.exe"
    export RANLIB="$TOOLCHAIN_PATH/llvm-ranlib.exe"
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
    export PERL5LIB="$OPENSSL_SRC/util/perl:$PERL5LIB"
    
    echo "Using CC: $CC"
    
    # Verify compiler exists
    if [ ! -f "$CC" ]; then
        echo "ERROR: Compiler not found: $CC"
        return 1
    fi
    
    echo "Configuring..."
    "$PERL_CMD" Configure "$target" \
        "-D__ANDROID_API__=$api" \
        no-shared \
        no-tests \
        no-ui-console \
        no-apps \
        "--prefix=$outdir" \
        "--openssldir=$outdir/ssl"
        
    if [ $? -ne 0 ]; then
        echo "ERROR: Configure failed for $arch"
        return 1
    fi
    
    echo "✓ Configuration successful for $arch"
    echo "Note: You need 'make' to complete the build"
    
    return 0
}

# Android targets
echo ""
echo "=== Starting Build Process ==="

build_openssl "armeabi-v7a" "android-arm" "21" "armv7a-linux-androideabi21-clang"
build_openssl "arm64-v8a" "android-arm64" "21" "aarch64-linux-android21-clang"
build_openssl "x86" "android-x86" "21" "i686-linux-android21-clang"
build_openssl "x86_64" "android-x86_64" "21" "x86_64-linux-android21-clang"

echo ""
echo "=== Summary ==="
echo "Configuration completed for all architectures."
echo "To complete the build, you need 'make'."
echo ""
echo "Next steps:"
echo "1. Install MSYS2 and run: pacman -S make"
echo "2. Or download GnuWin32 make"
echo "3. Then run 'make build_libs && make install_dev' in each configured directory."