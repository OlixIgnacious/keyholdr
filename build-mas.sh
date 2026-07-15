#!/bin/bash
set -e

# Builds the Mac App Store submission package: Keyholdr-MAS.app signed with
# App Store entitlements + provisioning profile, wrapped in a signed
# installer .pkg ready for `xcrun altool` / Transporter upload.
#
# Requires locally installed:
#   - "Apple Distribution: <name> (<team>)"              codesigning identity
#   - "3rd Party Mac Developer Installer: <name> (<team>)" identity
#   - the "Keyholdr MAS" provisioning profile in
#     ~/Library/MobileDevice/Provisioning Profiles/
#
# Keep VERSION/BUILD in sync with the CFBundleShortVersionString/
# CFBundleVersion in build.sh — App Store Connect needs a new BUILD for
# every resubmission.
VERSION="1.6.0"
BUILD="10"

echo "🚀 Building Keyholdr (MAS) in release mode..."
swift build -c release -Xswiftc -DMAS_BUILD

echo "📁 Creating App Bundle structure..."
APP_DIR="build/Keyholdr-MAS.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "✏️ Copying executables..."
cp .build/release/keyholdr "$APP_DIR/Contents/MacOS/Keyholdr"
chmod +x "$APP_DIR/Contents/MacOS/Keyholdr"
cp .build/release/keyholdr-cli "$APP_DIR/Contents/MacOS/keyholdr-cli"
chmod +x "$APP_DIR/Contents/MacOS/keyholdr-cli"

echo "🎨 Copying app icon..."
cp Sources/keyholdr/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.olixstudios.Keyholdr</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Keyholdr</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "📄 Embedding provisioning profile..."
PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/Keyholdr_MAS.provisionprofile"
if [[ ! -f "$PROFILE" ]]; then
    echo "❌ Provisioning profile not found at: $PROFILE"
    echo "   Download 'Keyholdr MAS' from developer.apple.com and place it there."
    exit 1
fi
cp "$PROFILE" "$APP_DIR/Contents/embedded.provisionprofile"

# Files copied in from outside the build tree (the provisioning profile,
# downloaded via a browser) can carry com.apple.quarantine, which App Store
# Connect rejects with ITMS-91109. Strip all extended attributes before signing.
echo "🧹 Clearing extended attributes..."
xattr -cr "$APP_DIR"

echo "🔏 Signing with MAS entitlements..."
APP_IDENTITY="${MAS_APP_SIGNING_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep 'Apple Distribution' | head -1 | awk -F'"' '{print $2}')}"
if [[ -z "$APP_IDENTITY" ]]; then
    echo "❌ No 'Apple Distribution' signing identity found."
    exit 1
fi
codesign --force --options runtime --timestamp \
    --entitlements "Sources/keyholdr/Keyholdr-CLI-MAS.entitlements" \
    --sign "$APP_IDENTITY" \
    "$APP_DIR/Contents/MacOS/keyholdr-cli"
codesign --force --options runtime --timestamp \
    --entitlements "Sources/keyholdr/Keyholdr-MAS.entitlements" \
    --sign "$APP_IDENTITY" \
    "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

echo "📦 Building installer package..."
INSTALLER_IDENTITY="${MAS_INSTALLER_SIGNING_IDENTITY:-$(security find-identity -v 2>/dev/null | grep '3rd Party Mac Developer Installer' | head -1 | awk -F'"' '{print $2}')}"
if [[ -z "$INSTALLER_IDENTITY" ]]; then
    echo "❌ No '3rd Party Mac Developer Installer' signing identity found."
    exit 1
fi
PKG_PATH="build/Keyholdr-$VERSION-MAS.pkg"
productbuild --component "$APP_DIR" /Applications \
    --sign "$INSTALLER_IDENTITY" \
    "$PKG_PATH"

echo "✅ Done! MAS package ready at $PKG_PATH (build $BUILD)."
echo "   Upload with: xcrun altool --upload-app -f \"$PKG_PATH\" -t macos ..."
echo "   or drag it into Transporter."
