#!/bin/bash
# Download complete OpenSSL source with all Perl modules

echo "Downloading complete OpenSSL 3.5.2 source..."

# Create download directory
cd /c/Users/user/Downloads
mkdir -p openssl-complete
cd openssl-complete

# Download the complete tarball
echo "Downloading openssl-3.5.2.tar.gz..."
curl -L -O https://www.openssl.org/source/openssl-3.5.2.tar.gz

# Verify download
if [ ! -f "openssl-3.5.2.tar.gz" ]; then
    echo "ERROR: Download failed"
    echo "Please manually download from: https://www.openssl.org/source/openssl-3.5.2.tar.gz"
    exit 1
fi

echo "Download successful. Extracting..."

# Extract
tar -xzf openssl-3.5.2.tar.gz

# Check if extraction was successful and Perl modules exist
if [ -d "openssl-3.5.2/util/perl/OpenSSL" ]; then
    echo "✓ Complete OpenSSL source extracted successfully"
    echo "✓ Perl modules found"
    
    # List the Perl modules
    echo "Available Perl modules:"
    ls -la openssl-3.5.2/util/perl/OpenSSL/
    
    echo ""
    echo "Complete OpenSSL source is now in:"
    echo "/c/Users/user/Downloads/openssl-complete/openssl-3.5.2"
    echo ""
    echo "Update your build script to use this path:"
    echo 'export OPENSSL_SRC="/c/Users/user/Downloads/openssl-complete/openssl-3.5.2"'
    
else
    echo "ERROR: Perl modules still not found after extraction"
    echo "There might be an issue with the download"
fi
