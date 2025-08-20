# Exit on error
$ErrorActionPreference = "Stop"

Write-Host "Building Android libraries..."

# Go to Rust folder
$rustDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "..\rust"
Push-Location $rustDir

# Clean previous builds
cargo clean

# Auto-detect NDK
if (-not $env:ANDROID_NDK_HOME) {
    if ($env:ANDROID_NDK) { $env:ANDROID_NDK_HOME = $env:ANDROID_NDK }
    elseif ($env:ANDROID_SDK_ROOT) {
        $ndkDirs = Get-ChildItem "$env:ANDROID_SDK_ROOT\ndk" -Directory | Sort-Object Name
        if ($ndkDirs.Count -eq 0) { throw "No NDK found in $env:ANDROID_SDK_ROOT\ndk" }
        $env:ANDROID_NDK_HOME = $ndkDirs[-1].FullName
        Write-Host "Using latest NDK at: $env:ANDROID_NDK_HOME"
    } else { throw "ANDROID_NDK_HOME environment variable must be set" }
}

# Check cargo-ndk
if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
    throw "cargo-ndk is not installed. Install it with: cargo install cargo-ndk"
}

# Create output directory
$jniLibsDir = "..\android\src\main\jniLibs"
if (-not (Test-Path $jniLibsDir)) { New-Item -ItemType Directory -Path $jniLibsDir | Out-Null }

# Android targets
$targets = @("aarch64-linux-android", "armv7-linux-androideabi", "i686-linux-android", "x86_64-linux-android")

foreach ($target in $targets) {
    Write-Host "--------------------------------------------"
    Write-Host "Building Rust library for $target..."
    Write-Host "--------------------------------------------"

    & cargo ndk -t $target -o $jniLibsDir build --release
}

Write-Host "============================================"
Write-Host "Android build completed successfully!"
Write-Host "Libraries are available at: $jniLibsDir"
Write-Host "============================================"

Pop-Location
