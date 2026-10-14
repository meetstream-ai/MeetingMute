# MeetingMute architecture

This document tells how MeetingMute operates and why it operates in that way. It is for contributors and reviewers. For installation and use, refer to the [README](../README.md).

## 1. Design rules

MeetingMute acts on windows of other apps. A wrong action can start a recording, invite a bot into a call, or close a window that the user needs. Thus the design rules put safety before coverage:

1. Do not act on a meeting app, a browser, an allowed app or MeetingMute itself.
2. Do not act on the window that the user works in.
3. Press only a button that declines a prompt. Compare the full label, not a part of it.
4. Press one time for each window. Do not fight the other app.
5. Close or hide a window only when the text clearly shows a call-start prompt of a known app.
6. Put each hidden window back.
7. Send nothing over the network and record no audio.

When the code cannot be sure, it does nothing. A prompt that stays on the screen is a small problem. A wrong press is a large problem.

## 2. Components

| Component | File | Function |
| --- | --- | --- |
| Registry | `registry/apps.json`, `Sources/MeetingMuteCore/Registry+Apps.swift` | The list of known apps, with evidence for each bundle ID. The generator script makes the Swift file. |
| Core rules | `Sources/MeetingMuteCore/` | Bundle ID match, dismiss policy, banner text, meeting detection and activity log. This code has no AppKit and builds on Linux. |
| App catalog | `Sources/MeetingMute/Model/AppCatalog.swift` | Finds installed and running apps. |
| Mute store | `Sources/MeetingMute/Model/MeetingPrompts.swift` | The app list, the mute modes, the settings and the activity log. |
| Audio input | `Sources/MeetingMute/Model/AudioInput.swift` | Reads which processes record audio. |
| Suppressor | `Sources/MeetingMute/Model/PromptSuppressor.swift` | The meeting state machine. It sends a request to the engine on each tick. |
| Engine | `Sources/MeetingMute/Model/AXEngine.swift` | All popup and banner work, on its own serial queue. |
| Views | `Sources/MeetingMute/Views/` | The main window, the menu bar panel, settings and onboarding. |

## 3. Meeting detection

The suppressor runs a timer every 0.5 seconds. When no meeting is active, it reads the audio state one time each second. During a meeting, it reads it on each tick.

The audio state comes from the Core Audio process list (`kAudioHardwarePropertyProcessObjectList`). For each process, the code reads `kAudioProcessPropertyIsRunningInput` and the bundle ID. This read needs no microphone permission. Apple gives no first macOS version for this property, so the code uses `AudioObjectHasProperty` at launch. If the property is not available, the code uses the default input device and the list of meeting apps that run.

`MeetingDetection.evaluate` decides if a call is on:

- A native meeting app (Zoom, Teams, Slack, Webex, FaceTime and others) with audio input is a meeting.
- The Zoom helper process `CptHost` is a meeting.
- The FaceTime system services (`com.apple.avconferenced`, `com.apple.TelephonyUtilities`) are a meeting.
- A browser with audio input is a meeting only when one of its window titles shows a call (for example "Meet - abc-defg-hij"). Voice search and dictation sites also use the microphone, thus a browser alone is not sufficient. The setting "Any browser microphone use is a meeting" removes this condition.
- The shared WebKit process (`com.apple.WebKit.GPU`) counts as Safari or Orion.

The state machine has two states: idle and in a meeting. A meeting starts after approximately one second of signal. It ends 30 seconds after the last signal, because a browser closes the microphone when the user mutes. After a meeting starts in a browser, it continues while that browser records, also on a different tab.

## 4. Popups

During a meeting, the engine examines the windows of each muted app that runs. A window is a candidate only when all of these conditions are true:

1. It is new. The engine keeps the time when it first saw each window. A window that was on the screen more than 8 seconds before the call starts is in the baseline. When the user resumes, the engine adds the windows on the screen to the baseline. When the user mutes an app during a call, the engine adds the windows of that app.
2. It is the size of a prompt (640 × 480 points or less). The size limit does not apply to apps with full-screen reminders, for example Dato.
3. It is not the main window or the focused window.
4. Its text contains a meeting word ("meeting", "call", "record", "join" and others), or a keyword from the registry entry of that app.

A baseline window becomes a candidate again when its size changes by more than 20 points. This rule finds a floating bar that grows into a "Meeting detected" card.

For each candidate, the engine does the first possible action in this sequence:

1. It presses the best decline button. The labels come from the `press` list of the app, then from a general list ("Not now", "Dismiss", "No thanks", "Don't Record" and others). A label in the `neverPress` list of the app is not pressed.
2. It presses the cancel button of the window, if that button has no label or a decline label.
3. It presses the close button of the window. Steps 3 and 4 occur only for an app in the registry. The text must also contain a phrase that only prompts use ("detected", "in a meeting", "start recording" and others).
4. It moves the window off the screen.

A pressed window can stay on the screen after 1.5 seconds. Then the engine moves it off the screen, with the same condition as steps 3 and 4. The engine puts hidden windows back when the meeting ends, when the user pauses or unmutes, and when MeetingMute quits. A `SIGTERM` handler also puts them back. At launch, the engine moves windows of known apps that are far off the screen back onto the screen.

Electron apps do not show their web content to Accessibility until an app asks. When a candidate has no text, the engine sets `AXManualAccessibility` on that app. It sets the attribute back to off after the meeting and when MeetingMute quits.

## 5. Notification banners

Banners are in the process `com.apple.notificationcenterui`. The engine looks for four subroles: `AXNotificationCenterBanner`, `AXNotificationCenterBannerStack`, `AXNotificationCenterAlert` and `AXNotificationCenterAlertStack`. It skips the history panel. The description of a banner starts with the name of the app, for example "Granola, Meeting detected, …". The engine compares that name with the names of the muted apps.

To close a banner, the engine uses the custom action of the banner. The action name has the form `Name:Close`. The label changes with the language of the system, thus the engine reads all translations of "Close" and "Clear All" from `NotificationCenter.app`. If two actions have the same label, the engine does nothing.

On macOS 26, all banners are in one shared host window. The engine does not hide or move that window, because that stops all later banners. The engine keeps the identifier of each closed banner for 10 seconds. Thus it does not close a banner two times while the banner goes off the screen.

By default, the engine closes banners only during meetings. The setting "Close notifications: Always" changes this.

## 6. Threads and performance

The views and the suppressor operate on the main thread. The engine operates on its own serial queue. The suppressor sends a request with a list of targets. A new request starts only after the last request is complete.

These limits make sure that a slow app does not stop MeetingMute:

- Each Accessibility call has a timeout of 0.3 seconds.
- Each tree walk stops after 300 nodes (600 nodes for Notification Center).
- Each scan stops after 2 seconds.
- Before an Accessibility call, the engine uses `CGWindowListCopyWindowInfo` to find new windows. This call is fast and needs no permission for position, size and owner.

The mute store keeps the app list in a cache until the installed apps or the list settings change. Popup and banner work runs only when a muted app runs, or when banners are set to close at all times.

## 7. Registry

`registry/apps.json` is the source for the list of known apps. Each entry has a category, bundle IDs or exact app names, a confidence label and a prompt type. It also has keywords, `press` and `neverPress` labels, an off switch and an evidence link. Refer to [CONTRIBUTING.md](../CONTRIBUTING.md#add-an-app) for the fields.

`scripts/gen_registry.py` checks the file and makes three outputs: the Swift list, [SUPPORTED_APPS.md](SUPPORTED_APPS.md) and the list in the README. CI fails if these outputs are not current.

The match rules prevent known errors:

- A bundle ID matches an app or its helpers (`com.google.Chrome.helper`), but not a different app with a longer name (`org.mozilla.firefoxdeveloperedition`).
- An app with no public bundle ID matches only by its full app name, never by a part of it.
- `excludeBundleIDs` removes apps that have the same name, for example Shadow PC.

## 8. Tests

`swift run CoreChecks` runs the checks for `MeetingMuteCore`. It needs only the Command Line Tools, and CI runs it on Linux. The checks include the bundle-ID errors that the research found and the dismiss policy for each type of prompt.

The Accessibility work cannot run in CI, because it needs the user's permission and real apps. Before a release, do the live test in [RELEASING.md](RELEASING.md#live-test).

`--demo` starts the app with sample data and with no Accessibility work. Use it for screenshots and for user interface changes.

## 9. Known limits

- A banner shows for a short time before the engine closes it.
- Some apps record with no prompt (Bluedot, Grain, Sybill). MeetingMute cannot stop this. The README tells the user to use the off switch in each app.
- Wispr Flow can offer to stop its meeting detection after many dismissed cards.
- 21 apps in the registry have no public bundle ID and match only by their app name.
- The build is not notarized. Users build from source.
