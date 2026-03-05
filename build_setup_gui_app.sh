#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build-gui"
APP_NAME="3DFlickFix Setup"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"

SRC_FILE="$PROJECT_DIR/3DFlickFixSetupApp.swift"
INSTALL_SCRIPT="$PROJECT_DIR/InstallServices.sh"
REMOVE_SCRIPT="$PROJECT_DIR/RemoveServices.sh"
RCLONE_BIN="$PROJECT_DIR/rclone"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found. Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

if [ ! -f "$SRC_FILE" ]; then
    echo "Source file not found: $SRC_FILE"
    exit 1
fi

for f in "$INSTALL_SCRIPT" "$REMOVE_SCRIPT" "$RCLONE_BIN"; do
    if [ ! -f "$f" ]; then
        echo "Required file missing: $f"
        exit 1
    fi
done

rm -rf "$BUILD_DIR"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>3DFlickFixSetup</string>
  <key>CFBundleIdentifier</key>
  <string>com.3dflickfix.setup</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSAppleScriptEnabled</key>
  <true/>
</dict>
</plist>
EOF

swiftc \
  -parse-as-library \
  -target arm64-apple-macosx13.0 \
  -framework SwiftUI \
  -framework AppKit \
  "$SRC_FILE" \
  -o "$APP_PATH/Contents/MacOS/3DFlickFixSetup"

cp "$INSTALL_SCRIPT" "$APP_PATH/Contents/Resources/InstallServices.sh"
cp "$REMOVE_SCRIPT" "$APP_PATH/Contents/Resources/RemoveServices.sh"
cp "$RCLONE_BIN" "$APP_PATH/Contents/Resources/rclone"
chmod +x "$APP_PATH/Contents/Resources/InstallServices.sh"
chmod +x "$APP_PATH/Contents/Resources/RemoveServices.sh"
chmod +x "$APP_PATH/Contents/Resources/rclone"

if [ -d "$TARGET_APP" ]; then
  rm -rf "$TARGET_APP"
fi

cp -R "$APP_PATH" "$TARGET_APP"
chmod +x "$TARGET_APP/Contents/MacOS/3DFlickFixSetup"

xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo "Built and installed: $TARGET_APP"
echo "Launch with: open \"$TARGET_APP\""
