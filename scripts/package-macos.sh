#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/iiiBar.app"
STAGE="$BUILD_DIR/dmg"
DMG="$BUILD_DIR/iiiBar.dmg"
WORKER_RESOURCES="$APP/Contents/Resources/worker"

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STAGE"

if [ ! -d "$ROOT/worker/node_modules" ]; then
  CI=1 NO_UPDATE_NOTIFIER=1 pnpm --dir "$ROOT/worker" install --frozen-lockfile
fi
CI=1 NO_UPDATE_NOTIFIER=1 pnpm --dir "$ROOT/worker" build

SWIFTPM_CACHE_PATH="$ROOT/mac/.build/swiftpm-cache" \
CLANG_MODULE_CACHE_PATH="$ROOT/mac/.build/module-cache" \
xcrun swift build \
  -c release \
  --package-path "$ROOT/mac" \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk

cp "$ROOT/mac/.build/release/iiiBar" "$APP/Contents/MacOS/iiiBar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>iiiBar</string>
  <key>CFBundleExecutable</key>
  <string>iiiBar</string>
  <key>CFBundleIdentifier</key>
  <string>dev.iii.iiibar</string>
  <key>CFBundleIconFile</key>
  <string>iiiBar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>iiiBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.3</string>
  <key>CFBundleVersion</key>
  <string>5</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp "$ROOT/mac/Resources/iiiBar.icns" "$APP/Contents/Resources/iiiBar.icns"

mkdir -p "$WORKER_RESOURCES"
cp "$ROOT/worker/package.json" "$WORKER_RESOURCES/package.json"
cp "$ROOT/worker/pnpm-lock.yaml" "$WORKER_RESOURCES/pnpm-lock.yaml"
cp -R "$ROOT/worker/dist" "$WORKER_RESOURCES/dist"
CI=1 NO_UPDATE_NOTIFIER=1 pnpm --dir "$WORKER_RESOURCES" install --prod --frozen-lockfile --ignore-scripts

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

cp -R "$APP" "$STAGE/iiiBar.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "iiiBar" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "$APP"
echo "$DMG"
