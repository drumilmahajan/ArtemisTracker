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

echo "✅ Built ArtemisTracker.app"
echo ""
echo "To run: open ArtemisTracker.app"
echo "Or:     ./ArtemisTracker.app/Contents/MacOS/ArtemisTracker"
