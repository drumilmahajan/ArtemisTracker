#!/bin/bash
set -e

echo "Building Galileo..."
cd "$(dirname "$0")"

# Build universal release (arm64 + x86_64)
swift build -c release --arch arm64 --arch x86_64 -Xswiftc -strict-concurrency=minimal 2>&1

# Create .app bundle
APP_DIR="Galileo.app/Contents"
rm -rf Galileo.app
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy universal binary
cp .build/apple/Products/Release/Galileo "$APP_DIR/MacOS/Galileo"

# Copy Info.plist
cp Sources/Galileo/Info.plist "$APP_DIR/Info.plist"

# Copy resources (textures)
cp Sources/Galileo/Resources/* "$APP_DIR/Resources/" 2>/dev/null || true

# Code sign if Developer ID certificate is available
SIGN_ID="Developer ID Application: Drumil Mahajan (69FNTL8QYK)"
if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
    codesign --force --options runtime --timestamp --entitlements Galileo.entitlements --sign "$SIGN_ID" Galileo.app
    echo "✅ Built and signed Galileo.app"
else
    echo "✅ Built Galileo.app (unsigned)"
fi
echo ""
echo "To run: open Galileo.app"
echo "Or:     ./Galileo.app/Contents/MacOS/Galileo"
