#!/usr/bin/env bash
#
# PrivaClip Application Packaging and Release Script
# Builds the native Apple Silicon binary, packages the .app bundle,
# embeds entitlements and icon assets, signs, and produces a distributable zip.
#

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="PrivaClip"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ZIP_ARTIFACT="$BUILD_DIR/$APP_NAME-macOS-arm64.zip"

echo "==> Building PrivaClip (Release configuration)..."
swift build -c release --product "$APP_NAME"

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "ERROR: Compiled binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Packaging $APP_NAME.app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 1. Copy binary
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 2. Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# 3. Copy AppIcon.icns
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# 4. Sign app bundle with entitlements
echo "==> Signing application bundle..."
if [ -n "${DEVELOPER_ID:-}" ]; then
    echo "Signing with Developer ID: $DEVELOPER_ID"
    codesign --force --deep --options runtime --timestamp \
        --entitlements "Resources/PrivaClip.entitlements" \
        --sign "$DEVELOPER_ID" "$APP_BUNDLE"
else
    echo "Signing with ad-hoc signature (local execution)..."
    codesign --force --deep --options runtime \
        --entitlements "Resources/PrivaClip.entitlements" \
        --sign - "$APP_BUNDLE"
fi

echo "==> Verifying signature & entitlements..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
codesign -d --entitlements - "$APP_BUNDLE"

# 5. Create zip archive
echo "==> Creating distributable archive: $ZIP_ARTIFACT..."
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_ARTIFACT"

echo
echo "=========================================="
echo "🎉 Build & Packaging Complete!"
echo "   App Bundle: $APP_BUNDLE"
echo "   Zip File:   $ZIP_ARTIFACT"
echo "=========================================="
