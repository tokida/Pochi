#!/bin/bash

APP_NAME="Pochi"
APP_BUNDLE="$APP_NAME.app"

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create Bundle Structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "Creating AppIcon.icns..."
if [ -f "AppIcon.png" ]; then
    mkdir -p AppIcon.iconset
    sips -z 16 16     AppIcon.png --out AppIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     AppIcon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   AppIcon.png --out AppIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 AppIcon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null

    iconutil -c icns AppIcon.iconset
    cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf AppIcon.iconset
fi

echo "Building with Swift Package Manager..."

# Build for arm64 (Apple Silicon)
swift build -c release --arch arm64 2>&1
ARM64_RESULT=$?

if [ $ARM64_RESULT -ne 0 ]; then
    echo "arm64 build failed."
    exit 1
fi
echo "arm64 build successful."

# Copy arm64 binary
cp .build/arm64-apple-macosx/release/Pochi "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Attempt x86_64 build for universal binary
echo "Attempting x86_64 build..."
swift build -c release --arch x86_64 2>&1
X86_RESULT=$?

if [ $X86_RESULT -eq 0 ]; then
    echo "x86_64 build successful. Creating universal binary..."
    lipo -create \
        .build/arm64-apple-macosx/release/Pochi \
        .build/x86_64-apple-macosx/release/Pochi \
        -output "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
    echo "Universal binary created."
else
    echo "x86_64 build skipped (arm64 only)."
fi

echo "Signing application..."
# Ad-hoc signing is required for microphone permissions to work properly even locally
codesign --force --deep --sign - "$APP_BUNDLE"

echo "------------------------------------------------"
echo "Build Complete: $APP_BUNDLE"
echo "To run, use: open $APP_BUNDLE"
echo ""
echo "MCP Setup (Claude Code):"
echo "  eval \$(./$APP_BUNDLE/Contents/MacOS/$APP_NAME --mcp-install)"
echo ""
echo "MCP Setup (Claude Desktop):"
echo "  ./$APP_BUNDLE/Contents/MacOS/$APP_NAME --mcp-config"
echo "------------------------------------------------"
