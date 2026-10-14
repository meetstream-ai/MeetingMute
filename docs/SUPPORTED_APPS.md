# Supported apps

MeetingMute knows **86 apps** that interrupt you when a call starts (registry version 2026.10.13). Any other app can be added by hand from the + button.

Generated from [`registry/apps.json`](../registry/apps.json). To add or fix an app, edit that file and run `python3 scripts/gen_registry.py`. Every bundle ID needs a public source: a Homebrew cask, the Mac App Store, an MDM recipe, source code, or the app's own `Info.plist` (`mdls -name kMDItemCFBundleIdentifier /Applications/App.app`).

**Match** says how MeetingMute recognises the app: *bundle ID* (confirmed by a primary source), *bundle ID (inferred)* (one secondary source), or *app name* (no public bundle ID yet, so only the exact app name is used).

## Notetakers (56)

| App | Match | Prompt | Turn it off in the app | Source |
|---|---|---|---|---|
| Altar AI | `com.electron.altar-app` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/altar-ai.json) |
| Alter | app name: *Alter* | Records without asking | Not documented | [link](https://alterhq.com/download) |
| Amie | `so.amie.electron-app` | Own popup window | Amie › Settings › turn off fully-automatic recordings | [link](https://formulae.brew.sh/api/cask/amie.json) |
| Anarlog | `com.hyprnote.stable`<br>`com.hyprnote.nightly`<br>`com.hyprnote.staging`<br>`com.hyprnote.dev`<br>`com.hyprnote.desktop` | Own popup window | Anarlog › Settings › General › Notifications › Microphone detection | [link](https://github.com/fastrepl/anarlog/blob/HEAD/apps/desktop/src-tauri/tauri.conf.stable.json) |
| Attention | app name: *Attention* | Not documented | Not documented | [link](https://docs.attention.com/core-features/desktop-app) |
| Avoma | app name: *Avoma* | Not documented | Not documented | [link](https://www.avoma.com/download) |
| Bluedot | app name: *Bluedot* | Records without asking | Not documented | [link](https://www.bluedothq.com/blog/bluedot-2-1) |
| Capy | `com.digitalworkroom.capybara` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=capy&entity=macSoftware) |
| Circleback | app name: *Circleback* | Own popup window | Circleback › Settings › Notifications › Detect meetings | [link](https://support.circleback.ai/en/articles/10460578-record-meetings-with-the-desktop-app) |
| Claap | app name: *Claap* | Not documented | Not documented | [link](https://help.claap.io/en/articles/15588967-recording-and-transcribing-your-meetings-on-the-desktop-app-mac) |
| Clari Copilot | app name: *Clari Copilot*, *Clari-Copilot* | Not documented | Not documented | [link](https://github.com/Installomator/Installomator/blob/main/fragments/labels/claricopilot.sh) |
| Cluely | `com.cluely.app` (inferred) | Not documented | Not documented | [link](https://github.com/Neved4/homebrew-tap/blob/HEAD/Casks/cluely.rb) |
| Detto | `io.gremble.detto` | Not documented | Not documented | [link](https://github.com/Gremble-io/Detto/blob/HEAD/Detto/Sources/Detto/Info.plist) |
| Fathom | `video.fathom.electron` | Own popup window | Fathom › Capture Off for the meeting | [link](https://github.com/autopkg/dataJAR-recipes/blob/master/Fathom/Fathom.download.recipe) |
| Fellow | `com.electron.fellow` | Not documented | Not documented | [link](https://github.com/autopkg/dataJAR-recipes/blob/master/Fellow/Fellow.download.recipe) |
| Fireflies | app name: *Fireflies*, *Fireflies.ai* | Own popup window | Fireflies › Settings › Notifications › Notify when a meeting is detected | [link](https://guide.fireflies.ai/articles/1208704416-getting-started-with-the-fireflies-desktop-app) |
| Fyxer | app name: *Fyxer*, *Fyxer Notetaker* | Own popup window | Not documented | [link](https://support.fyxer.com/en/articles/13544508-install-the-notetaker-desktop-app-and-record-your-first-meeting) |
| Grain | app name: *Grain* | Records without asking | Not documented | [link](https://support.grain.com/en/articles/12022918-desktop-capture) |
| Granola | `com.granola.app`<br>`com.getgranola.app` | Own popup window | Granola › Settings › Notifications | [link](https://formulae.brew.sh/api/cask/granola.json) |
| Hedy | `bot.hedy.mobile` | Not documented | Hedy › Settings › Automation & Data › Meeting app detection | [link](https://formulae.brew.sh/api/cask/hedy.json) |
| Heizen Meets | app name: *Heizen*, *Heizen Meets* | Not documented | Heizen › Settings › Notifications › Auto-detected meetings | [link](https://docs.heizen.work/meets/automatic-meeting-detection/) |
| Jamie | `com.jamie.app` | Not documented | Jamie › Settings › Notifications › Auto-Detected Meetings | [link](https://formulae.brew.sh/api/cask/jamie.json) |
| Jiminny | app name: *Jiminny* | Own popup window | Not documented | [link](https://help.jiminny.com/en/articles/15373740-invisible-recording-with-the-jiminny-desktop-app) |
| Junior | app name: *Junior* | Not documented | Not documented | [link](https://docs.myjunior.ai/junior-for-mac-and-windows/meeting-detection/) |
| Krisp | `ai.krisp.krispMac` | Own popup window | Krisp › Settings › Call status notifications | [link](https://formulae.brew.sh/api/cask/krisp.json) |
| Laxis | app name: *Laxis* | Not documented | Not documented | [link](https://help.laxis.com/ai-meeting-assistant/desktop/) |
| Limitless (discontinued) | `ai.limitless.desktop` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/limitless.json) |
| Littlebird | `com.genos.littlebird` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/littlebird.json) |
| MeetGeek | app name: *MeetGeek* | Not documented | Not documented | [link](https://support.meetgeek.ai/en/articles/13745672-meetgeek-desktop-app-quickstart-guide) |
| Meetily | `com.meetily.ai` | Notification banner | Meetily › Settings › Notifications › Meeting reminders | [link](https://github.com/Zackriya-Solutions/meetily/blob/HEAD/frontend/src-tauri/tauri.conf.json) |
| Meeting Intelligence | `com.michaelcosmi.MeetingIntelligence` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=meeting+intelligence&entity=macSoftware) |
| MeetingRecorder | `com.meetingrecorder.app` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/meetingrecorder.json) |
| Meetly | `com.edgeai.meetly` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=meetly&entity=macSoftware) |
| MeetMic | `ltd.iwt.QuickWhisper` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/meetmic.json) |
| MeetNotes AI | `com.samsonice.meetnotes` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=meetnotes&entity=macSoftware) |
| Minute | `dev.minute.app` | Own popup window | Not documented | [link](https://github.com/mraza007/minute/blob/HEAD/src-tauri/tauri.conf.json) |
| MinuteForge | `com.danielw.MinuteForge` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=minuteforge&entity=macSoftware) |
| Narada | `stepanok.com.Meetings-Recorder` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=minutes+meeting&entity=macSoftware) |
| NoteAI | `com.stefrasoft.noteai` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=noteai&entity=macSoftware) |
| Noted | `com.digitalworkroom.noted.mac` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=noted&entity=macSoftware) |
| Notion | `notion.id` | Not documented | Notion › Settings › Notifications › Desktop meeting detection notifications | [link](https://formulae.brew.sh/api/cask/notion.json) |
| Notta | app name: *Notta* | Not documented | Not documented | [link](https://www.notta.ai) |
| Omi | `com.friend-app-with-wearable.ios12` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=omi&entity=macSoftware) |
| Otter | `com.otterai.desktop`<br>`ai.otter.otter` (inferred) | Not documented | Otter › Desktop App Settings › Meeting Detection › Off | [link](https://appcatalog.cloud/apps/otter) |
| Plaud | `ai.plaud.desktop.plaud` | Not documented | Plaud › Preferences › Recording › Meeting detection | [link](https://formulae.brew.sh/api/cask/plaud.json) |
| Quill | app name: *Quill*, *Quill Meetings* | Not documented | Not documented | [link](https://github.com/quillmeetings/quill-cli/blob/HEAD/src/doctor.js) |
| Read AI | app name: *Read AI* | Not documented | Not documented | [link](https://www.read.ai/desktop) |
| Rewind (discontinued) | `com.memoryvault.MemoryVault` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/rewind.json) |
| RiverScript | `com.riverscript.desktop` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/riverscript.json) |
| ScreenApp | `io.screenapp.app` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=screenapp&entity=macSoftware) |
| Shadow | app name: *Shadow* | Records without asking | Not documented | [link](https://www.shadow.do) |
| Supernormal | app name: *Supernormal* | Own popup window | Supernormal › Settings › Preferences › Capture Meetings Automatically | [link](https://help.supernormal.com/en/articles/11801221-how-do-i-capture-a-meeting) |
| Superpowered (discontinued) | `com.todesktop.2203083ko7eiitd` (inferred) | Not documented | Not documented | [link](https://download.todesktop.com/2203083ko7eiitd/td-latest-mac.json) |
| Sybill | app name: *Sybill* | Records without asking | Not documented | [link](https://help.sybill.ai/en/articles/16761658-getting-started-with-sybill-your-first-week) |
| Tablo | `Ideanology.Transcriblo` | Not documented | Not documented | [link](https://itunes.apple.com/search?term=tablo&entity=macSoftware) |
| tl;dv | `io.tldv.desktop` | Not documented | tl;dv › Settings › Desktop App › Live meeting notifications | [link](https://github.com/apfelq/mdm-pkg-creator/blob/1a10bc15251196b402e2b24f80c5ed682106fca7/apps-examples/tldv.yaml) |

## Dictation and transcription (9)

| App | Match | Prompt | Turn it off in the app | Source |
|---|---|---|---|---|
| Amical | `com.amical.desktop` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/amical.json) |
| GhostPepper | `com.github.matthartman.ghostpepper` | Not documented | Not documented | [link](https://github.com/matthartman/ghost-pepper/blob/HEAD/GhostPepper/Info.plist) |
| MacParakeet | `com.macparakeet.MacParakeet` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/macparakeet.json) |
| MacWhisper | `com.goodsnooze.MacWhisper` | Not documented | MacWhisper › Settings › Record Meetings › Automatic Meeting Notifications | [link](https://formulae.brew.sh/api/cask/macwhisper.json) |
| Monologue | `com.zeitalabs.jottleai` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/monologue.json) |
| Muesli | `com.muesli.app` | Own popup window | Not documented | [link](https://formulae.brew.sh/api/cask/muesli.json) |
| OpenWhispr | `com.gizmolabs.openwhispr` | Not documented | OpenWhispr › Settings › App › Preferences › Notifications › Meeting detection | [link](https://formulae.brew.sh/api/cask/openwhispr.json) |
| Vibe | `github.com.thewh1teagle.vibe` | Own popup window | Vibe › Settings › Meeting detection | [link](https://github.com/thewh1teagle/vibe/blob/main/desktop/src-tauri/tauri.conf.json) |
| Wispr Flow | `com.electron.wispr-flow` | Own popup window | Wispr Flow › Settings › Notetaker › Automatically detect any call | [link](https://formulae.brew.sh/api/cask/wispr-flow.json) |

## Recorders (1)

| App | Match | Prompt | Turn it off in the app | Source |
|---|---|---|---|---|
| Zight | `com.linebreak.CloudAppMacOSX` | Not documented | Zight › Preferences › General › Auto-detect meetings | [link](https://formulae.brew.sh/api/cask/zight.json) |

## Meeting reminders (19)

| App | Match | Prompt | Turn it off in the app | Source |
|---|---|---|---|---|
| Akiflow | `com.akiflow.akiflow` | Own popup window | Akiflow › Settings › Notifications | [link](https://formulae.brew.sh/api/cask/akiflow.json) |
| BigReminder | `app.bigreminder` | Full-screen reminder | Not documented | [link](https://apps.apple.com/app/id6757824417) |
| Calerto | `com.Calarm` | Full-screen reminder | Not documented | [link](https://apps.apple.com/us/app/id6747410132) |
| Dato | `com.sindresorhus.Dato` | Full-screen reminder | Not documented | [link](https://apps.apple.com/us/app/dato/id1470584107) |
| Dot | `com.dot.app` | Own popup window | Dot › Preferences › Meeting Reminders | [link](https://formulae.brew.sh/api/cask/dot.json) |
| Fantastical | `com.flexibits.fantastical2.mac`<br>`85C27NK92C.com.flexibits.fantastical2.mac.helper` | Notification banner | System Settings › Notifications › Fantastical | [link](https://formulae.brew.sh/api/cask/fantastical.json) |
| JustJoin | `com.grc.JustJoin` | Not documented | Not documented | [link](https://apps.apple.com/search?term=justjoin) |
| Meeting Hero | `com.cole-labs.meeting-hero.release` | Own popup window | Not documented | [link](https://apps.apple.com/app/id1519894533) |
| Meeting Reminder In Your Face | `com.bluebanana-software.inyourface` | Full-screen reminder | Not documented | [link](https://apps.apple.com/us/app/meeting-reminder-in-your-face/id1476964367) |
| MeetingBar | `leits.MeetingBar` | Notification banner | MeetingBar › Preferences › Notifications | [link](https://github.com/leits/MeetingBar/blob/master/MeetingBar/Notifications/NotificationScheduler.swift) |
| MinMaxCal | `com.mikemcquaid.MinMaxCal` | Full-screen reminder | Not documented | [link](https://github.com/MikeMcQuaid/MinMaxCal/blob/main/project.yml) |
| Morgen | `com.todesktop.210203cqcj00tw1` | Own popup window | Not documented | [link](https://formulae.brew.sh/api/cask/morgen.json) |
| Next - Meeting Alerts | `tools.emily.next` | Not documented | Not documented | [link](https://apps.apple.com/app/id6758521669) |
| Next Meeting | `com.nspindel.nextmeeting.osx` | Not documented | Not documented | [link](https://itunes.apple.com/lookup?id=1017470484) |
| Notion Calendar | `com.cron.electron` | Own popup window | Notion Calendar › Settings › Notifications | [link](https://formulae.brew.sh/api/cask/notion-calendar.json) |
| Quick Join | `com.wegenerlabs.Quick-Join` | Not documented | Not documented | [link](https://itunes.apple.com/lookup?id=1511437420) |
| Remind | `com.christopherdoyle.remind` | Full-screen reminder | Not documented | [link](https://apps.apple.com/app/id6787806895) |
| Slapss | `com.cancetin.slapss` | Full-screen reminder | Not documented | [link](https://apps.apple.com/us/app/id6767488326) |
| Soonie | `co.numberfive.Slicings` | Not documented | Not documented | [link](https://apps.apple.com/search?term=soonie) |

## AI assistants (1)

| App | Match | Prompt | Turn it off in the app | Source |
|---|---|---|---|---|
| ChatGPT | `com.openai.codex`<br>`com.openai.chat` | Not documented | Not documented | [link](https://formulae.brew.sh/api/cask/chatgpt.json) |

## Never touched

Meeting apps and browsers are protected and never acted on: Zoom, Microsoft Teams, Slack, Webex, Discord, FaceTime, WhatsApp, Skype, GoTo Meeting, RingCentral, Amazon Chime, Telegram, Signal, Tuple, Around, Tencent Meeting, Element, Chrome, Arc, Dia, Safari, Edge, Brave, Firefox, Vivaldi, Opera, Chromium, Orion, Zen, Comet, ChatGPT Atlas and Sidekick.

MeetingMute also knows 49 dictation apps, screen recorders and assistants that use the microphone but never prompt at call start (superwhisper, Willow, VoiceInk, Loom, CleanShot X…). It never suggests them as notetakers.
