#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

CONFIGURATION=${CONFIGURATION:-release}
APP_NAME="InputTimeline"
PRODUCT_NAME="$APP_NAME.app"
BUILD_DIR="$PROJECT_DIR/.build/$CONFIGURATION"
PRODUCT_DIR="$PROJECT_DIR/dist"
APP_DIR="$PRODUCT_DIR/$PRODUCT_NAME"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "Building $APP_NAME ($CONFIGURATION)..."
swift build --package-path "$PROJECT_DIR" -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PROJECT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Ad-hoc signing helps macOS treat the generated bundle as a proper app.
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built app bundle at:"
echo "  $APP_DIR"
