#!/bin/bash
set -e

echo "🚀 Building Keyholdr in release mode..."
swift build -c release

echo "📁 Creating App Bundle structure..."
APP_DIR="build/Keyholdr.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "✏️ Copying executable..."
cp .build/release/keyholdr "$APP_DIR/Contents/MacOS/Keyholdr"
chmod +x "$APP_DIR/Contents/MacOS/Keyholdr"

echo "📝 Creating Info.plist..."
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Keyholdr</string>
    <key>CFBundleIdentifier</key>
    <string>com.olixstudios.Keyholdr</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Keyholdr</string>
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

echo "🛑 Stopping any running instances of Keyholdr..."
pkill Keyholdr || true

echo "✨ Launching Keyholdr..."
open "$APP_DIR"
echo "✅ Done! Keyholdr is running in the menu bar."
