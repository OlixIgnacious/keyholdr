#!/bin/bash
set -e

echo "🚀 Building KeyHolder in release mode..."
swift build -c release

echo "📁 Creating App Bundle structure..."
APP_DIR="build/KeyHolder.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "✏️ Copying executable..."
cp .build/release/keyholder "$APP_DIR/Contents/MacOS/KeyHolder"
chmod +x "$APP_DIR/Contents/MacOS/KeyHolder"

echo "📝 Creating Info.plist..."
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>KeyHolder</string>
    <key>CFBundleIdentifier</key>
    <string>com.olixstudios.KeyHolder</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KeyHolder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "🛑 Stopping any running instances of KeyHolder..."
pkill KeyHolder || true

echo "✨ Launching KeyHolder..."
open "$APP_DIR"
echo "✅ Done! KeyHolder is running in the menu bar."
