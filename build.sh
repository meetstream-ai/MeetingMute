#!/usr/bin/env bash
# Builds MeetingMute.app into ./build. Pass --run to launch it afterwards.
set -euo pipefail

cd "$(dirname "$0")"
APP="build/MeetingMute.app"
BUNDLE_ID="com.rohanganesh.MeetingMute"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MeetingMute" "$APP/Contents/MacOS/MeetingMute"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"

# Sign with a stable self-signed identity (./setup-signing.sh) so the Accessibility grant
# survives rebuilds. Ad-hoc signing works too, but macOS forgets the grant every build.
IDENTITY="MeetingMute Dev"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
else
    echo "warning: \"$IDENTITY\" not found; ad-hoc signing (run ./setup-signing.sh)" >&2
    codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
fi

echo "Built $(pwd)/$APP"

if [[ "${1:-}" == "--run" ]]; then
    pkill -x MeetingMute 2>/dev/null && sleep 1 || true
    open "$APP"
fi
