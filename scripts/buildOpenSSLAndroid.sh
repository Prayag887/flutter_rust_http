#!/bin/bash
# Build OpenSSL 1.1.1w for Android using NDK r27 on Windows

# Configuration
export ANDROID_NDK_ROOT="/c/Users/user/AppData/Local/Android/Sdk/ndk/27.0.12077973"
export OPENSSL_SRC="/c/Users/user/Downloads/openssl-complete/openssl-1.1.1w"
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

echo "Building OpenSSL 1.1.1w for Android..."
echo "OpenSSL Source: $OPENSSL_SRC"
echo "NDK Root: $ANDROID_NDK_ROOT"
echo "Output: $OPENSSL_OUT"
echo ""

# Verify prerequisites
echo "=== Verifying Prerequisites ==="

# Check OpenSSL source
if [ ! -f "$OPENSSL_SRC/Configure" ]; then
    echo "ERROR: Configure script not found at $OPENSSL_SRC"
    exit 1
fi
echo "✓ OpenSSL Configure script found"

# Check NDK
if [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "ERROR: Android NDK not found at $ANDROID_NDK_ROOT"
    exit 1
fi
echo "✓ Android NDK found"

# Check Perl
if ! "$PERL_CMD" -v &> /dev/null; then
    echo "ERROR: Perl is not working"
    exit 1
fi
echo "✓ Perl is working"

# Check if we have make
if ! command -v make &> /dev/null; then
    echo "WARNING: 'make' not found. You'll need to install it to complete the build."
    echo "   Install MSYS2 and run: pacman -S make"
    USE_MAKE=false
else
    echo "✓ make found"
    USE_MAKE=true
fi

echo ""

# Build function for OpenSSL 1.1.1
build_openssl_1_1_1() {
    local arch="$1"
    local target="$2"
    local api="$3"
    local cc="$4"
    local ar="$5"
    local ranlib="$6"
    
    echo "=== Building OpenSSL 1.1.1w for $arch ==="
    
    local outdir="$OPENSSL_OUT/$arch"
    rm -rf "$outdir"
    mkdir -p "$outdir"
    
    # Change to OpenSSL source directory
    cd "$OPENSSL_SRC" || return 1
    
    # Clean previous build
    if [ -f "Makefile" ]; then
        if [ "$USE_MAKE" = true ]; then
            make clean 2>/dev/null || true
        else
            rm -f Makefile configdata.pm
        fi
    fi
    
    # Set environment variables for OpenSSL 1.1.1
    export CC="$cc"
    export AR="$ar"
    export RANLIB="$ranlib"
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
    
    # OpenSSL 1.1.1 specific environment variables
    export ANDROID_API="$api"
    export ANDROID_PLATFORM="android-$api"
    export ANDROID_TOOLCHAIN="$TOOLCHAIN_PATH"
    
    echo "Using CC: $CC"
    echo "Using AR: $AR"
    echo "Target: $target"
    echo "API Level: $api"
    
    # Verify compiler exists
    if [ ! -f "$CC" ]; then
        echo "ERROR: Compiler not found: $CC"
        return 1
    fi
    
    # Configure OpenSSL 1.1.1
    echo "Configuring..."
    "$PERL_CMD" Configure "$target" \
        no-shared \
        no-tests \
        no-ui-console \
        no-apps \
        "--prefix=$outdir" \
        "--openssldir=$outdir/ssl" \
        "-D__ANDROID_API__=$api"
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Configure failed for $arch"
        return 1
    fi
    
    echo "✓ Configuration successful for $arch"
    
    if [ "$USE_MAKE" = true ]; then
        echo "Building libraries..."
        make -j$(nproc)
        
        if [ $? -ne 0 ]; then
            echo "ERROR: Build failed for $arch"
            return 1
        fi
        
        echo "Installing..."
        make install_dev
        
        if [ $? -ne 0 ]; then
            echo "ERROR: Install failed for $arch"
            return 1
        fi
        
        echo "✓ Successfully built and installed $arch"
    else
        echo "Configuration complete. Install 'make' to build libraries."
    fi
    
    return 0
}

# Android targets for OpenSSL 1.1.1
echo "=== Starting Build Process ==="

# OpenSSL 1.1.1 uses different target names and requires explicit tool paths
build_openssl_1_1_1 "armeabi-v7a" "android-arm" "21" \
    "$TOOLCHAIN_PATH/armv7a-linux-androideabi21-clang.cmd" \
    "$TOOLCHAIN_PATH/llvm-ar.exe" \
    "$TOOLCHAIN_PATH/llvm-ranlib.exe"

build_openssl_1_1_1 "arm64-v8a" "android-arm64" "21" \
    "$TOOLCHAIN_PATH/aarch64-linux-android21-clang.cmd" \
    "$TOOLCHAIN_PATH/llvm-ar.exe" \
    "$TOOLCHAIN_PATH/llvm-ranlib.exe"

build_openssl_1_1_1 "x86" "android-x86" "21" \
    "$TOOLCHAIN_PATH/i686-linux-android21-clang.cmd" \
    "$TOOLCHAIN_PATH/llvm-ar.exe" \
    "$TOOLCHAIN_PATH/llvm-ranlib.exe"

build_openssl_1_1_1 "x86_64" "android-x86_64" "21" \
    "$TOOLCHAIN_PATH/x86_64-linux-android21-clang.cmd" \
    "$TOOLCHAIN_PATH/llvm-ar.exe" \
    "$TOOLCHAIN_PATH/llvm-ranlib.exe"

# Summary
echo ""
echo "=== Build Summary ==="

if [ "$USE_MAKE" = true ]; then
    echo ""
    echo "Build Results:"
    
    SUCCESS_COUNT=0
    TOTAL_COUNT=4
    
    for arch in "armeabi-v7a" "arm64-v8a" "x86" "x86_64"; do
        libpath="$OPENSSL_OUT/$arch/lib"
        if [ -d "$libpath" ] && [ -f "$libpath/libssl.a" ] && [ -f "$libpath/libcrypto.a" ]; then
            echo "  $arch: ✓ SUCCESS (libssl.a, libcrypto.a)"
            ((SUCCESS_COUNT++))
        else
            echo "  $arch: ✗ FAILED"
        fi
    done
    
    echo ""
    echo "Successfully built: $SUCCESS_COUNT/$TOTAL_COUNT architectures"
    
    if [ $SUCCESS_COUNT -gt 0 ]; then
        echo ""
        echo "OpenSSL libraries are available in: $OPENSSL_OUT"
        echo ""
        echo "For each architecture, you'll find:"
        echo "  - lib/libssl.a"
        echo "  - lib/libcrypto.a"
        echo "  - include/ (headers)"
        echo ""
        echo "Integration example:"
        echo "  - Link: -lssl -lcrypto"
        echo "  - Include: -I$OPENSSL_OUT/arm64-v8a/include"
    fi
    
else
    echo "Configuration completed for all architectures."
    echo ""
    echo "To complete the build:"
    echo "1. Install MSYS2: https://www.msys2.org/"
    echo "2. Open MSYS2 terminal and run: pacman -S make"
    echo "3. Re-run this script"
    echo ""
    echo "Or manually complete the build:"
    echo "cd $OPENSSL_SRC && make && make install_dev"
fi