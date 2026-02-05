#!/bin/bash

APP_NAME="Pochi"
APP_BUNDLE="$APP_NAME.app"
SOURCES="Sources/main.swift Sources/Pochi.swift Sources/AudioRecorder.swift Sources/RecordingListView.swift Sources/SettingsManager.swift"

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

echo "Compiling sources..."
# Compile using swiftc
# Note: We invoke swiftc with SDK path explicitly if needed, but default usually works.
# We target macOS 11.0 to ensure SwiftUI/AVFoundation features are available.
swiftc $SOURCES \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macosx11.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework IOKit \
    -framework Carbon

if [ $? -eq 0 ]; then
    echo "Compilation successful (arm64)."

    # Also build x86_64 if possible (for universal binary)
    echo "Attempting x86_64 build..."
    swiftc $SOURCES \
        -o "$APP_BUNDLE/Contents/MacOS/${APP_NAME}_x86_64" \
        -target x86_64-apple-macosx11.0 \
        -framework SwiftUI \
        -framework AppKit \
        -framework AVFoundation \
        -framework IOKit \
        -framework Carbon 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "x86_64 build successful. Creating universal binary..."
        lipo -create \
            "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
            "$APP_BUNDLE/Contents/MacOS/${APP_NAME}_x86_64" \
            -output "$APP_BUNDLE/Contents/MacOS/${APP_NAME}_universal"
        mv "$APP_BUNDLE/Contents/MacOS/${APP_NAME}_universal" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
        rm "$APP_BUNDLE/Contents/MacOS/${APP_NAME}_x86_64"
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
    echo "------------------------------------------------"
else
    echo "Compilation failed."
    exit 1
fi
