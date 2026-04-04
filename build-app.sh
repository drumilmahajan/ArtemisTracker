#!/bin/bash
set -e

echo "Building Artemis Tracker..."
cd "$(dirname "$0")"

# Build release
swift build -c release -Xswiftc -strict-concurrency=minimal 2>&1

# Create .app bundle
APP_DIR="ArtemisTracker.app/Contents"
rm -rf ArtemisTracker.app
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy binary
cp .build/release/ArtemisTracker "$APP_DIR/MacOS/ArtemisTracker"

# Copy Info.plist
cp Sources/ArtemisTracker/Info.plist "$APP_DIR/Info.plist"

# Code sign if Developer ID certificate is available
SIGN_ID="Developer ID Application: Drumil Mahajan (69FNTL8QYK)"
if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
    codesign --force --deep --options runtime --sign "$SIGN_ID" ArtemisTracker.app
    echo "✅ Built and signed ArtemisTracker.app"
else
    echo "✅ Built ArtemisTracker.app (unsigned)"
fi
echo ""
echo "To run: open ArtemisTracker.app"
echo "Or:     ./ArtemisTracker.app/Contents/MacOS/ArtemisTracker"
