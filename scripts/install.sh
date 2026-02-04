#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Connor.app"
APP_DIR="$PROJECT_DIR/.build/$APP_NAME"
INSTALL_DIR="$HOME/Applications"

# Build the app bundle
echo "Building $APP_NAME..."
"$SCRIPT_DIR/build-app.sh"

# Create ~/Applications if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Remove old installation if present
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    echo "Removing existing installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME"
fi

# Copy the app bundle
echo "Installing to $INSTALL_DIR/$APP_NAME..."
cp -R "$APP_DIR" "$INSTALL_DIR/"

echo "Done! You can now open $APP_NAME from ~/Applications"
