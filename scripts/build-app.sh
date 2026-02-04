#!/bin/bash
set -e

# Build the Swift package
swift build -c release

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/.build/Connor.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean and create app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/Connor" "$MACOS_DIR/"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/Connor/Resources/Info.plist" "$CONTENTS_DIR/"

# Compile Assets.xcassets to Assets.car and AppIcon.icns
ASSETS_DIR="$PROJECT_DIR/Sources/Connor/Resources/Assets.xcassets"
if [ -d "$ASSETS_DIR" ]; then
    xcrun actool "$ASSETS_DIR" \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist /tmp/connor-assets-info.plist
fi

echo "Built: $APP_DIR"
echo ""
echo "To run: open $APP_DIR"
