#!/bin/bash
set -e
BUNDLE="NotchLookup.app"
swift build -c release
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp .build/release/NotchLookup "$BUNDLE/Contents/MacOS/"
cp Sources/NotchLookup/Info.plist "$BUNDLE/Contents/"
codesign --force --sign "NotchLookup Dev" --entitlements NotchLookup.entitlements "$BUNDLE"
echo "Done. Run: open $BUNDLE"
