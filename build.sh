#!/usr/bin/env bash
# Builds MeetingMute.app into ./build.
#
#   ./build.sh               build for this Mac
#   ./build.sh --run         build, then (re)launch it
#   ./build.sh --universal   build for Apple silicon and Intel
#   ./build.sh --zip         also write build/MeetingMute.zip
set -euo pipefail

cd "$(dirname "$0")"
APP="build/MeetingMute.app"
BUNDLE_ID="ai.meetstream.MeetingMute"
RUN=0; UNIVERSAL=0; ZIP=0
for arg in "$@"; do
    case "$arg" in
        --run) RUN=1 ;;
        --universal) UNIVERSAL=1 ;;
        --zip) ZIP=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

python3 scripts/gen_registry.py --check

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ $UNIVERSAL == 1 ]]; then
    swift build -c release --product MeetingMute --triple arm64-apple-macosx14.0
    swift build -c release --product MeetingMute --triple x86_64-apple-macosx14.0
    lipo -create .build/arm64-apple-macosx/release/MeetingMute .build/x86_64-apple-macosx/release/MeetingMute \
        -output "$APP/Contents/MacOS/MeetingMute"
else
    swift build -c release --product MeetingMute
    cp "$(swift build -c release --show-bin-path)/MeetingMute" "$APP/Contents/MacOS/MeetingMute"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a stable self-signed identity (./setup-signing.sh) so the Accessibility grant
# survives rebuilds. Ad-hoc signing works too, but macOS forgets the grant every build.
IDENTITY="MeetingMute Dev"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    SIGN_AS="$IDENTITY"
else
    echo "warning: \"$IDENTITY\" not found; ad-hoc signing (run ./setup-signing.sh)" >&2
    SIGN_AS="-"
fi
# Synced folders (iCloud Drive, File Provider) can add Finder info right after the bundle is
# created, which codesign rejects; clear it and retry.
for attempt in 1 2 3 4 5; do
    xattr -cr "$APP"
    if codesign --force --sign "$SIGN_AS" --identifier "$BUNDLE_ID" "$APP" 2>/dev/null; then break; fi
    if [[ $attempt == 5 ]]; then codesign --force --sign "$SIGN_AS" --identifier "$BUNDLE_ID" "$APP"; fi
    sleep 0.5
done

echo "Built $(pwd)/$APP ($(lipo -archs "$APP/Contents/MacOS/MeetingMute"))"

if [[ $ZIP == 1 ]]; then
    rm -f build/MeetingMute.zip
    ditto -c -k --keepParent "$APP" build/MeetingMute.zip
    echo "Zipped $(pwd)/build/MeetingMute.zip"
fi

if [[ $RUN == 1 ]]; then
    # Quit politely so MeetingMute puts any hidden popups back before it exits.
    for id in "$BUNDLE_ID" com.rohanganesh.MeetingMute; do
        osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1 || true
    done
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x MeetingMute >/dev/null || break; sleep 0.3; done
    open "$APP"
fi
