# Release procedure

This procedure makes a new release of MeetingMute. Do all the steps in sequence.

## 1. Before you start

- Make sure that you have the Command Line Tools (`xcode-select --install`).
- Make sure that the main branch has all the changes for the release.
- For a signed download, you must have a Developer ID Application certificate for MeetStream and a notarytool profile. Without them, you can only make an unsigned build.

## 2. Checks

1. Run the registry check:
   ```sh
   python3 scripts/gen_registry.py --check
   ```
2. Run the core checks:
   ```sh
   swift run CoreChecks
   ```
3. Make a release build. Make sure that the build shows no warnings:
   ```sh
   swift build -c release
   ```

## Live test

The Accessibility work cannot run in CI. Do this test on a Mac with real apps before each release.

1. Build and open the app:
   ```sh
   ./build.sh --run
   ```
2. Give the Accessibility permission to MeetingMute.
3. Install two or more apps from the registry that show a call-start prompt, for example Granola and Wispr Flow.
4. Mute one app. Keep one app allowed.
5. Start a Zoom call or a Google Meet call.
6. Make sure that the activity log shows "Meeting started".
7. Make sure that the prompt of the muted app closes, and that the prompt of the allowed app stays.
8. Make sure that no button that records or joins was pressed in the muted app.
9. Click Pause. Make sure that hidden prompts come back.
10. End the call. After 30 seconds, make sure that the activity log shows "Meeting ended".
11. Send a test notification from the muted app, if it has one. Make sure that it closes during a call only.
12. If a step fails, copy the diagnostics from Settings and open an issue.

## 3. Version

1. In `Resources/Info.plist`, increase `CFBundleShortVersionString` (for example 1.2.0) and `CFBundleVersion` (for example 3).
2. In `CHANGELOG.md`, add a section for the new version with the date.
3. Commit the two files, open a pull request and get an approval.

## 4. Build

1. Make a universal build and a zip file:
   ```sh
   ./build.sh --universal --zip
   ```
2. For an unsigned release, go to step 6.

## 5. Sign and notarize

1. Sign the app with the Developer ID and the hardened runtime:
   ```sh
   codesign --force --options runtime --timestamp \
     --sign "Developer ID Application: <MeetStream team>" build/MeetingMute.app
   ```
2. Make the zip file again:
   ```sh
   ditto -c -k --keepParent build/MeetingMute.app build/MeetingMute.zip
   ```
3. Send the zip file for notarization:
   ```sh
   xcrun notarytool submit build/MeetingMute.zip --keychain-profile meetstream --wait
   ```
4. Staple the ticket to the app:
   ```sh
   xcrun stapler staple build/MeetingMute.app
   ```
5. Make the zip file one more time, so that it contains the stapled app.

## 6. Publish

1. Tag the release:
   ```sh
   git tag v1.2.0
   git push origin v1.2.0
   ```
2. Make the GitHub release with the zip file and the changelog section:
   ```sh
   gh release create v1.2.0 build/MeetingMute.zip --title "MeetingMute 1.2.0" --notes-file <changelog section>
   ```
3. For an unsigned release, add this note: the first time, right-click the app and click Open.
