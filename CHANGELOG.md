# Changelog

## 1.1.0 (2026-10-13)

MeetingMute is now a [MeetStream](https://meetstream.ai) open-source project.

### Added
- **86 known apps**, up from 17: notetakers, dictation apps, recorders and meeting reminders, each with an evidence link for its bundle ID ([list](docs/SUPPORTED_APPS.md)). The list lives in `registry/apps.json`.
- Per-app decline buttons: MeetingMute presses *Not now*, *Dismiss* or *Don't Record*, and never a button that records, joins, invites a bot or changes the other app's settings.
- Meeting card with the source app, a timer, the number of prompts silenced, and **Pause for this meeting**.
- Live menu bar icon, Quit item, open at login, and an option to hide the Dock icon.
- "Turn it off at the source" hints: the exact setting in each app that stops its prompt.
- Browser calls: Google Meet, Teams, Whereby and others count as meetings when a tab looks like a call. Option to count any browser microphone use.
- Notification scope: close muted apps' banners during meetings (default) or always.
- Suggested apps: apps that start using the microphone are suggested with a NEW badge and never muted until you say so.
- Search, category groups, activity log grouped by day with repeats folded, a lifetime "silenced" counter.
- About tab, Help menu links and **Copy for a Bug Report**.
- New app icon.
- Docs: [ARCHITECTURE.md](docs/ARCHITECTURE.md) (design and reasons), [RELEASING.md](docs/RELEASING.md) (release steps and a live test), CONTRIBUTING, SECURITY.
- `swift run CoreChecks`, demo mode for screenshots (`--demo`), universal and zip build options, CI.

### Changed
- Popups are only acted on when they are new, prompt-sized, not the window you're in, and about a meeting, and each gets one press. A window is only closed or hidden when it clearly reads as a known app's call-start prompt. Previously any small window of a muted app could be closed.
- Banners close by Notification Center's own *Close* action in every language, not just English, and only from muted apps.
- Meetings start after about a second of signal and end 30 seconds after it stops, so muting your microphone doesn't end the meeting. A browser call stays on while the browser holds the microphone, even in another tab.
- Popup and banner handling runs off the main thread, with a 0.3 s timeout on every Accessibility call and a 2 s limit per scan.
- Matching uses one rule everywhere (exact bundle ID or its helpers), which fixes Firefox Developer Edition and Notion Calendar being mistaken for other apps.
- Bundle ID is now `ai.meetstream.MeetingMute`. Settings from 1.0 carry over; Accessibility must be allowed once more.

### Fixed
- Popups moved off screen are put back when MeetingMute is quit with `kill` or `pkill`, and on the next launch if it crashed.
- "Mute all" no longer mutes browsers or other apps found using the microphone.
- The animated background pauses when the window is in the background.

## 1.0.0 (2026-10-13)

First release by Rohan Ganesh: per-app mute, three modes, meeting detection through Core Audio, popup and banner dismissal through Accessibility, onboarding, rows and tiles, menu bar and settings.
