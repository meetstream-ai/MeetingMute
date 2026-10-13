# Contributing to MeetingMute

Thanks for helping. The most useful contributions are small: a notetaker we don't know yet, a bundle ID we only guessed, or a popup that slips through.

## Set up

```sh
xcode-select --install          # Command Line Tools; the full Xcode app is not needed
git clone https://github.com/meetstream-ai/MeetingMute.git
cd MeetingMute
./setup-signing.sh              # optional: keeps the Accessibility grant across rebuilds
./build.sh --run
swift run CoreChecks            # the logic checks; also run in CI
```

## Add an app

Every built-in app lives in [`registry/apps.json`](registry/apps.json). One entry:

```json
{
  "name": "Granola", "category": "notetaker",
  "bundleIDs": ["com.granola.app"],
  "confidence": "confirmed", "prompt": "window",
  "keywords": ["meeting detected", "take notes"],
  "press": [], "neverPress": ["Take Notes"],
  "offSwitch": "Granola › Settings › Notifications",
  "evidence": "https://formulae.brew.sh/api/cask/granola.json"
}
```

| Field | What it means |
| --- | --- |
| `category` | `notetaker`, `dictation`, `recorder`, `calendar` or `assistant`. |
| `bundleIDs` | Exact `CFBundleIdentifier` values. Helpers (`<id>.helper`) match automatically. |
| `appNames` | Only when no bundle ID is public: the exact app name, never a fragment. Use `excludeBundleIDs` for other apps with the same name. |
| `confidence` | `confirmed` (primary source), `inferred` (one secondary source) or `name-only`. |
| `prompt` | `window`, `banner`, `fullscreen`, `auto-record` or `unknown`. Set `"fullScreen": true` if its reminder can cover the screen. |
| `keywords` | Words that appear in its prompt, beyond the usual "meeting", "call", "record"… |
| `press` | Buttons that **decline** its prompt, best first. |
| `neverPress` | Buttons that record, join, invite a bot or change its settings. |
| `offSwitch` | Where to turn the prompt off inside the app. |
| `evidence` | A public link that shows the bundle ID. |

Find a bundle ID on a Mac that has the app:

```sh
mdls -name kMDItemCFBundleIdentifier "/Applications/App Name.app"
# or
osascript -e 'id of app "App Name"'
```

Good public sources: the Homebrew cask (`https://formulae.brew.sh/api/cask/<token>.json`, see the `uninstall quit:` and `zap` entries), the Mac App Store (`https://itunes.apple.com/lookup?id=<app id>`), an AutoPkg or MDM recipe, or the app's source code. Please don't add a guessed ID: a wrong guess does no harm, but it hides the fact that the real one is missing.

Then:

```sh
python3 scripts/gen_registry.py    # updates the Swift list, docs/SUPPORTED_APPS.md and the README
swift run CoreChecks
```

Watch for these traps (they're all real):

- Renamed apps keep their old ID: Anarlog is `com.hyprnote.stable`, Notion Calendar is `com.cron.electron`, Zight is `com.linebreak.CloudAppMacOSX`.
- One vendor, two apps: the new ChatGPT app is `com.openai.codex`, ChatGPT Classic is `com.openai.chat`.
- Two apps, one name: `Buzz.app` is a transcription app *or* Block's chat app; "Shadow" is a notetaker *or* a cloud gaming app.
- Generic framework IDs (`com.electron.*`, `com.todesktop.*`) must be listed in full.

## Report a popup that slips through

1. In MeetingMute, open **Settings › General › Copy for a Bug Report** and paste it into a [bug report](https://github.com/meetstream-ai/MeetingMute/issues/new?template=bug-report.yml).
2. Add a screenshot of the popup.
3. Best of all: open **Accessibility Inspector** (it ships with Xcode) while the popup is up, and note its window subrole, its text and its button labels. That tells us which button declines it.

## Code

- `Sources/MeetingMuteCore` is pure logic with no AppKit; put anything testable there and add checks to `Sources/CoreChecks/main.swift`.
- `Sources/MeetingMute/Model/AXEngine.swift` does all Accessibility work on a background queue. Keep AX calls out of the main thread.
- Never press a button by a partial label match, and never act on meeting apps (`MeetingApp.isProtected`).
- Match the surrounding style: short functions, a doc comment on anything non-obvious, no new dependencies.

## Pull requests

- One topic per PR.
- `swift build -c release`, `swift run CoreChecks` and `python3 scripts/gen_registry.py --check` pass.
- For UI changes, a before and after screenshot (`open build/MeetingMute.app --args --demo` helps).

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
