# Ramble — Build Report (State of the App)

> Snapshot of everything built so far, the tech stack, and exactly how each piece
> works. Written so you can formulate the MVP roadmap with full knowledge of what
> already exists. Current as of Session 1 completion.

---

## TL;DR

A working, installable Android app — **~4,650 lines of Dart across 26 files**, 0
static-analysis errors, **48.7 MB release APK** live on GitHub. The entire core loop
works **100% offline with no backend and no accounts**: you talk, it transcribes
on-device, classifies the note into 1 of 7 types, structures it into a document, and
Miko (the character) reacts. Everything else (cloud LLM, sync, audio files, stores)
is additive and not yet built.

- **Repo:** https://github.com/ziyaad-mallick/ramble
- **Release/APK:** https://github.com/ziyaad-mallick/ramble/releases/tag/v1.0.0
- **Local path:** `C:\Users\testi\Desktop\Mallick\the lab\ramble.ai`

---

## 1. TECH STACK

### Client (the whole app today)
| Layer | Choice | Why |
|---|---|---|
| Framework | **Flutter 3.x / Dart 3** | one codebase → Android + iOS; best custom-paint perf for Miko + waveform |
| Language | Dart (sound null-safety) | — |
| Local DB | **Hive** (`hive`, `hive_flutter`) | fast key-value, notes/projects stored as JSON strings |
| Speech→text | **`speech_to_text` v7** | on-device, offline, free, native OS engine |
| Notifications | **`flutter_local_notifications` v21** | reminders + Miko alerts |
| Fonts | **`google_fonts`** | Press Start 2P, DM Sans, JetBrains Mono — no asset bundling |
| Share/export | **`share_plus` v10** | export note as markdown |
| Date/format | **`intl`** | timestamps |
| Misc | `permission_handler`, `collection`, `flutter_animate`, `cupertino_icons` | mic perms, utils, motion |
| AI (current) | **Rule-based Dart** (no network) | intent detection + Miko responses run fully offline |

### Backend
**None yet.** App is entirely local. (Planned: Cloudflare Worker for the LLM proxy,
Supabase for optional sync — neither built.)

### Build toolchain (installed & working on this machine)
- Flutter SDK: `C:\src\flutter`
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot`
- Android SDK: `%LOCALAPPDATA%\Android\Sdk` (platforms 34 & 35, build-tools 35)
- Gradle 9.1.0 (cached locally), AGP 8.x, Kotlin 2.x
- Release build cmd: `flutter build apk --release`
- App ID: `com.ramble.app` · label "Ramble" · version 1.0.0+1

---

## 2. WHAT'S BUILT — FILE BY FILE

**Total: 26 Dart files, ~4,650 LOC.**

### Design system (1 file, 174 LOC) — the visual contract
`theme/ramble_theme.dart` — the single source of truth. Full "90s retro pixel kawaii"
palette (Miko Purple, Pixel Pink, Cream, Deep Navy + extended), the per-note-type color
map, the type scale (Press Start 2P / DM Sans / JetBrains Mono), spacing/geometry
constants, and `RambleScheme` (light + dark) accessed via `context.ramble`. Every widget
pulls from here — no hardcoded colors anywhere.

### Models (3 files, 257 LOC) — the data contract
- `note.dart` (189) — `Note` (7 `NoteType`s, each with its own `fieldKeys` template),
  `ExtractedItem` (task/question/decision/person), `Reminder`. Full JSON round-trip.
- `project.dart` (39) — `Project` (Inbox = empty projectId).
- `miko_response.dart` (29) — `MikoResponse` + 7 trigger types.

### Services (8 files, 1,496 LOC) — the logic
- `speech_service.dart` (57) — on-device STT wrapper; partial results + sound levels.
- `intent_service.dart` (232) — **rule-based classifier**: scores a transcript against
  keyword/pattern signals for all 7 types, returns (type, confidence).
- `formatter_service.dart` (610) — the heaviest brain file. Turns a raw transcript into a
  full `Note`: title, key quote, per-type structured fields, tags (frequency minus
  stopwords), extracted tasks/questions/decisions/people, reminder date phrases, and
  project auto-assignment by name match. All heuristic, never throws.
- `miko_service.dart` (347) — **"Miko Talks Back"** engine. Analyzes a new note against
  history, fires at most ONE response in priority order (contradiction → repeated task →
  connection → recurring theme → stale reactivation → first-in-project) or stays silent.
  Lowercase, dry voice; uses real dates/topics from your notes.
- `storage_service.dart` (128) — Hive persistence for notes + projects.
- `settings_service.dart` (26) — name, API key, mikoEnabled, onboarded flags.
- `notification_service.dart` (88) — local notifications, reminder scheduling, fails soft.
- `app_events.dart` (8) — global `dataVersion` notifier; screens rebuild on change.

### Screens (5 files, 1,625 LOC) — the flows
- `onboarding_screen.dart` (160) — one-screen welcome: Miko, wordmark, name, "let's go".
- `home_screen.dart` (314) — greeting, Miko, project chips + Inbox, recent notes list,
  big record FAB. Rebuilds reactively on new notes.
- `recording_screen.dart` (350) — the signature screen: live timer, **Miko Waveform**,
  live transcript, stop/cancel, then a "making sense of it" processing state that runs the
  formatter + Miko and routes to the note.
- `note_detail_screen.dart` (462) — the structured document: type badge, editable title,
  key quote, per-type fields, tasks (checkable) / questions / decisions / people, tags,
  collapsible transcript, metadata footer, markdown share, delete. Shows Miko's response
  card at top if he reacted.
- `settings_screen.dart` (339) — name, Miko toggle, optional API key (offline vs smart),
  about, reset onboarding.

### Widgets (9 files, 1,134 LOC) — the kit
- `miko/miko_painter.dart` (198) — **Miko drawn entirely in code** (CustomPainter, pixel
  grid): bubble, bevel border, face, blush, heart, side waveform bars; 7 states
  (idle/recording/processing/talking/contradiction/excited/sleeping).
- `miko/miko_character.dart` (109) — animates Miko (idle blink, state motion).
- `miko/miko_waveform.dart` (287) — **the brand signature**: a single pixel dot riding a
  sine wave, purple→pink gradient, comet trail, amplitude follows your voice.
- `ramble_card.dart` (88), `ramble_button.dart` (121), `ramble_badge.dart` (68) — the
  hard-pixel-shadow component kit (press = shadow collapses + element shifts).
- `note_card.dart` (77), `miko_response_card.dart` (114) — composed list/feedback widgets.

---

## 3. THE CORE LOOP (what actually works end to end)

```
tap mic
  → speech_service streams partial transcript + audio level (offline)
  → Miko Waveform rides your voice live
tap stop
  → intent_service picks 1 of 7 types (rule-based)
  → formatter_service builds the structured Note (title, key quote, fields,
    tags, tasks/questions/decisions/people, reminders, project)
  → storage_service saves it (Hive)
  → notification_service schedules any reminders
  → miko_service decides if Miko says something (and what)
  → note_detail_screen opens with the document + Miko's reaction
home updates reactively
```

**No internet. No account. No API key required.** That's the whole point of the slice.

---

## 4. WHAT'S NOT BUILT YET (so the roadmap is accurate)

Nothing below exists in code today:
- ❌ Cloud LLM brain (real Claude-powered intent/Miko/synthesis) — currently rule-based
- ❌ Ask Your Notes / semantic search / embeddings
- ❌ Thought Graph, Mindmap Canvas, Person profiles
- ❌ Project deep-view (brief, question pool, decision log), Inbox swipe-assign screen
- ❌ Audio file recording + playback (we transcribe live but don't save the .m4a)
- ❌ Speaker diarization / multi-voice / silence trimming
- ❌ Any backend (Cloudflare Worker), any cloud sync (Supabase), any auth
- ❌ Cross-note intelligence (contradiction engine across a project, weekly synthesis)
- ❌ Personal vocabulary engine, spaced repetition, momentum score
- ❌ App icon (still default Flutter icon), splash, signed release, store assets
- ❌ Monetization (RevenueCat / Free vs Pro gating)
- ❌ iOS build (code is cross-platform but never compiled for iOS)

---

## 5. PLATFORM DECISIONS (locked)

- **WhatsApp** → deferred to the **paid plan** (week 2+); needs business verification + cost.
- **Telegram** → **scrapped** (your call). The app is in-app capture only for now.
- **iOS** → **cannot be built on the iPad.** Swift Playgrounds on iPadOS only builds native
  Swift apps, not Flutter (no Flutter SDK / Xcode for iPadOS). The real path is **cloud CI
  — Codemagic or Xcode Cloud** — which compiles the iOS binary on Apple's servers with no
  Mac required. The iPad is still useful for **testing** via TestFlight.
- **Android** → primary target; APK builds and installs today.

---

## 6. HONEST QUALITY NOTES

- The "AI" today is **rule-based heuristics**, not an LLM. It's genuinely decent for
  structure/tags/intent but won't match Claude-quality nuance until Session 3 wires the
  cloud brain. Set expectations accordingly when you test.
- Miko's character art is **code-drawn pixel art** — faithful to your reference, fully
  animatable, but can be refined further (it's geometry, not a hand-drawn asset).
- App uses light state management (singletons + one notifier) — deliberate; upgrade only
  where a complex screen (graph/search) needs it.
- Default app icon still in place — addressed in the polish session.

---

*Build method: Opus 4.8 architect (contracts) → parallel Haiku agents (code) →
Sonnet COO (integrate/debug/build/push). See docs/ARCHITECTURE.md for the full roadmap.*
