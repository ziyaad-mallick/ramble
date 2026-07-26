# Ramble

**Talk at your phone. We'll make sense of it.**

A voice-note app for people who think out loud. You ramble; it transcribes, structures, files, and
answers back. The whole pipeline — speech recognition *and* the language model — runs on the device.

Android, Flutter.

---

## On-device by default

Ramble uses [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) for local inference and the
platform's own speech recogniser for transcription. There is no backend, no account, and no API key.
Your voice notes are not a training corpus for anyone, and the app works on a plane.

That constraint is the product, not a limitation to apologise for. Mobile data is metered where I
built this, connectivity drops daily, and the phones around me are mid-range Androids — so "does it
run without a network on hardware nobody would call fast" is the only benchmark that mattered.

## What it does

- **Record and transcribe** — `speech_to_text` with a `record`-based capture path, wrapped so the
  OS recogniser and the local model are interchangeable behind one service.
- **Structure it** — the local model turns a rambling transcript into a titled note with a summary
  and tags, sorted into projects.
- **Miko** — the character at the centre of the app. Notes get a response, not just a filing.
- **Reminders** — if you mention a deadline out loud, it schedules a local notification.
- **Export** — share as text or render to PDF.
- **Local storage** — Hive. Nothing syncs, because there's nowhere to sync to.

## Architecture

Services are split so that every external dependency sits behind a swappable interface —
`speech_service` / `os_stt_service` for capture, `local_llm_service` for inference,
`storage_service` for persistence. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full
picture and [`docs/BUILD_REPORT.md`](docs/BUILD_REPORT.md) for build notes.

```
lib/
  models/     note, project, miko_response
  services/   audio, speech, transcription, local_llm, storage, notifications, …
  screens/    onboarding, home, recording, note_detail, settings
  widgets/    shared UI
  theme/
```

## Build

```bash
flutter pub get
dart run flutter_launcher_icons     # first time only
flutter run
```

Requires Flutter SDK ^3.9.2 and Android SDK 24+.

## Related

- [voicenote](https://github.com/ziyaad-mallick/voicenote) — the same idea on desktop, in Python,
  with Vosk for ASR and Ollama for structuring.

## Status

Built 2026. Releases an APK; iOS is scaffolded but not built or tested.
