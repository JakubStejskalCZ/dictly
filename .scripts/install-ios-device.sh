#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="DictlyiOS"
CONFIGURATION="Debug"
DERIVED_DATA="$WORKSPACE_DIR/DictlyiOS/build"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/DictlyiOS.app"

echo "==> Detecting connected iPhone..."
DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null \
  | grep -E "iPhone|iPad" \
  | grep -v "Simulator" \
  | awk '{print $NF}' \
  | head -1)

if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: No iPhone/iPad found. Connect your device via USB and trust this Mac."
  exit 1
fi

echo "==> Found device: $DEVICE_ID"

echo "==> Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -workspace "$WORKSPACE_DIR/Dictly.xcworkspace" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  build 2>&1 | xcpretty 2>/dev/null || cat

echo "==> Installing on device..."
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_PATH"

echo "==> Done. Launch Dictly on your iPhone."
