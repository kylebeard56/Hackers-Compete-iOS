#!/usr/bin/env bash
set -euo pipefail

DEVICE_UDID="${HACKERS_SIM_UDID:-660575F1-D86B-4291-95CA-0EE3A02F301F}"
DERIVED_DATA_PATH="${HACKERS_DERIVED_DATA_PATH:-/tmp/HackersDerivedData}"
SCHEME="${HACKERS_SIM_SCHEME:-Production}"
CONFIGURATION="${HACKERS_SIM_CONFIGURATION:-$SCHEME}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/Hackers.app"
BUNDLE_ID="${HACKERS_SIM_BUNDLE_ID:-com.tigermindlabs.hackers.compete}"

xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b

xcodebuild \
  -project Hackers.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"
