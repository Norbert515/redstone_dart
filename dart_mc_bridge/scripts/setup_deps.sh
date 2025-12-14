#!/bin/bash

# Setup script for dart_mc_bridge dependencies
# Downloads pre-built dart_shared_library binaries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$PROJECT_DIR/native/deps/dart_dll"

# dart_shared_library release
RELEASE_VERSION="v0.2.0"
RELEASE_URL="https://github.com/fuzzybinary/dart_shared_library/releases/download/$RELEASE_VERSION"

# Detect platform
case "$(uname -s)" in
    Darwin*)
        PLATFORM="macos"
        if [[ "$(uname -m)" == "arm64" ]]; then
            echo "Warning: Pre-built binaries are for x64. ARM64 requires building from source."
            echo "You may need to run with Rosetta or build dart_shared_library manually."
        fi
        ARCHIVE="dart_dll-macos-x64.tar.gz"
        ;;
    Linux*)
        PLATFORM="linux"
        ARCHIVE="dart_dll-linux-x64.tar.gz"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows"
        ARCHIVE="dart_dll-windows-x64.zip"
        ;;
    *)
        echo "Unsupported platform: $(uname -s)"
        exit 1
        ;;
esac

echo "Setting up dart_shared_library for $PLATFORM..."

# Create deps directory
mkdir -p "$DEPS_DIR"
cd "$DEPS_DIR"

# Download release
echo "Downloading $ARCHIVE..."
curl -L -o "$ARCHIVE" "$RELEASE_URL/$ARCHIVE"

# Extract
echo "Extracting..."
if [[ "$ARCHIVE" == *.zip ]]; then
    unzip -o "$ARCHIVE"
else
    tar -xzf "$ARCHIVE"
fi

# Cleanup archive
rm "$ARCHIVE"

# Create expected directory structure
mkdir -p include lib bin

# Move files to expected locations (adjust based on actual archive structure)
# The exact paths depend on how the release is packaged
if [[ -f "dart_dll.h" ]]; then
    mv dart_dll.h include/
fi
if [[ -f "dart_api.h" ]]; then
    mv dart_api.h include/
fi
if [[ -f "dart_native_api.h" ]]; then
    mv dart_native_api.h include/
fi

echo ""
echo "Setup complete!"
echo "dart_shared_library installed to: $DEPS_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_DIR/native"
echo "  2. cmake -B build -DDART_DLL_PATH=$DEPS_DIR"
echo "  3. cmake --build build"
