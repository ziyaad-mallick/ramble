# Ramble — Complete Architecture & MVP Roadmap

> Chief Architect document. Every Claude Code session reads this first.
> Status legend: ✅ done · 🔨 in progress · ⬜ not started

---

## 0. THE STACK (how we build)

**Model orchestration per session ("gstack"):**

```
Opus 4.8 (Chief Architect)  → first ~20% of session
   reviews state vs this doc → designs the slice → writes file-level
   contracts + Haiku agent specs → dispatches the swarm → /model switch out

Haiku agents (Workers)       → spawned in parallel, model: haiku, max effort
   each owns ONE file against a locked spec. Hold own context. Cheap + fast.

Sonnet 4.6 (COO)            → remaining ~80% of session
   integrates outputs → flutter analyze → fixes bugs with DIRECT EDITS
   (never respawns an agent for a 2-line fix) → builds APK → commits → pushes
```

Rule that saves the most tokens: **Sonnet patches integration bugs inline.** Only
respawn a Haiku agent if a whole file is wrong/missing.

**Why this is efficient:** expensive model (Opus) only thinks; bulk typing is Haiku
(cheapest); the tight debug loop is Sonnet (mid). Proven in Sessions 0–1.

**Hard rule for long ops:** block in-turn on builds/installs (10-min tool wait),
never background — background tasks don't reliably wake the agent.

---

## 1. APP ARCHITECTURE (client)

Flutter + Dart, single codebase → Android now, iOS when a Mac/CI is available.

```
lib/
├── main.dart                      # init Hive + services, first-run gate, theme
├── theme/ramble_theme.dart        # ✅ THE design system — single source of truth
├── models/
│   ├── note.dart                  # ✅ Note (7 types, per-type fieldKeys), ExtractedItem, Reminder
│   ├── project.dart               # ✅ Project (+ Inbox = projectId '')
│   ├── miko_response.dart         # ✅ MikoResponse + 7 triggers
│   ├── person.dart                # ⬜ S2 — person profile from mentions
│   └── graph.dart                 # ⬜ S2 — GraphNode/GraphEdge for Thought Graph
├── services/
│   ├── speech_service.dart        # ✅ on-device STT (speech_to_text)
│   ├── intent_service.dart        # ✅ rule-based 7-type classifier
│   ├── formatter_service.dart     # ✅ transcript → structured Note (rule-based)
│   ├── miko_service.dart          # ✅ "Miko Talks Back" active-response engine
│   ├── storage_service.dart       # ✅ Hive persistence (notes, projects)
│   ├── settings_service.dart      # ✅ prefs, API key
│   ├── notification_service.dart  # ✅ local notifications / reminders
│   ├── app_events.dart            # ✅ global refresh ValueNotifier
│   ├── llm_client.dart            # ⬜ S3 — Cloud LLM path (Claude/OpenAI), key-gated
│   ├── embedding_service.dart     # ⬜ S2 — local embeddings + cosine search
│   ├── search_service.dart        # ⬜ S2 — Ask/Find/Filter over notes
│   ├── graph_service.dart         # ⬜ S2 — build Thought Graph from notes
│   ├── person_service.dart        # ⬜ S2 — aggregate person profiles
│   ├── vocab_service.dart         # ⬜ S3 — personal vocabulary engine
│   ├── audio_service.dart         # ⬜ S4 — record-to-file, silence trim, playback
│   └── sync_service.dart          # ⬜ S5 — Supabase pull/push (optional cloud)
├── screens/
│   ├── onboarding_screen.dart     # ✅
│   ├── home_screen.dart           # ✅
│   ├── recording_screen.dart      # ✅
│   ├── note_detail_screen.dart    # ✅
│   ├── settings_screen.dart       # ✅
│   ├── project_screen.dart        # ⬜ S2 — project view (brief, questions, tasks, people)
│   ├── inbox_screen.dart          # ⬜ S2 — unassigned notes, swipe to assign
│   ├── search_screen.dart         # ⬜ S2 — Ask Your Notes
│   ├── graph_screen.dart          # ⬜ S2 — Thought Graph canvas
│   └── person_screen.dart         # ⬜ S2 — person profile
└── widgets/
    ├── miko/ (painter, character, waveform)   # ✅ code-drawn Miko + signature wave
    ├── ramble_card / button / badge           # ✅ hard-pixel-shadow kit
    ├── note_card / miko_response_card          # ✅
    ├── graph_painter.dart                      # ⬜ S2 — CustomPainter constellation
    └── audio_scrubber.dart                     # ⬜ S4 — waveform + playback head
```

**State management:** intentionally light — singletons + a global `dataVersion`
ValueNotifier. Upgrade to Riverpod only if a screen needs fine-grained reactivity
(graph/search). Don't over-engineer.

**Persistence:** Hive (local JSON boxes). Vectors for search live in a Hive box too
(no sqlite-vss on mobile; cosine over in-memory float lists is fine < ~5k notes).

---

## 2. BACKEND ARCHITECTURE (only what the MVP truly needs)

The PRD wants Cloudflare Workers + WATI + diarization. For an 8-session MVP we cut
to the minimum that delivers the magic. **The app works 100% offline with zero
backend.** Backend is additive.

```
┌────────────┐   audio/text    ┌──────────────────────┐   ┌─────────────┐
│ Ramble app │ ───────────────▶│  Cloudflare Worker    │──▶│ Claude API  │ (LLM)
│ (Flutter)  │ ◀───────────────│  (api proxy + webhook)│   └─────────────┘
└────────────┘   structured    └──────────┬───────────┘
      │                                    │
      │ optional cloud sync                │ Telegram webhook
      ▼                                    ▼
┌─────────────┐                    ┌──────────────┐
│  Supabase   │                    │ Telegram Bot │  (capture channel)
│ (auth+db)   │                    └──────────────┘
└─────────────┘
```

**Why a Worker and not call Claude directly from the app?** API keys must never ship
in an APK. The Worker holds the secret key, the app calls the Worker. Free tier
(100k req/day) covers launch easily.

**Components:**
- **Cloudflare Worker** (`/backend/worker/`) — ⬜ S3. Two routes:
  - `POST /process` — app sends transcript → Worker calls Claude → returns structured note JSON. Lets us upgrade Miko's brain without shipping keys.
  - `POST /telegram` — Telegram webhook → transcribe (Whisper API) → process → reply in chat.
- **Supabase** — ⬜ S5, OPTIONAL. Auth (email/Google) + Postgres for cross-device sync. App is local-first; sync is opt-in. If user never signs in, nothing leaves the device.
- **Telegram Bot** — ⬜ S4. Free, instant, no approval. Built before WhatsApp.
- **WhatsApp (WATI/Twilio)** — ⬜ deferred to week 2. Needs business verification + $.

---

## 3. DATA MODEL (canonical — do not drift)

```
Note { id, title, type(NoteType×7), projectId, keyQuote,
       fields:Map<String,String> (keys = type.fieldKeys),
       rawTranscript, tags[], items[ExtractedItem{kind,text,done}],
       reminders[Reminder{text,dateTime}], confidence, createdAt, durationSeconds,
       + S2: audioPath?, embedding:List<double>? }
Project { id, name, description, colorValue, pinned, createdAt }
Person  { id(name-normalized), displayName, noteIds[], commitments[], questions[] }  (S2)
MikoResponse { trigger(7), message, relatedNoteId? }
GraphNode { noteId, x, y, type, connectionCount }  GraphEdge { aId, bId, weight }  (S2)
```

NoteType field templates already implemented in `NoteTypeX.fieldKeys`.

---

## 4. SESSION-BY-SESSION ROADMAP (8 sessions, ~1 week)

Each session = one coherent, demoable increment. APK pushed at the end of every one.

### ✅ SESSION 0–1 — Foundation + Core Loop  *(DONE)*
Rebrand→Ramble, full design system, Miko (character + waveform), core loop:
record → on-device transcribe → 7-type intent → structured doc → Miko talks back →
projects/inbox. Onboarding, home, recording, detail, settings. Offline rule-based AI.
**Demo:** talk → get a structured note → Miko reacts. APK v1.0.0 shipped.

### 🔨 SESSION 2 — Organize & Navigate  *(NEXT)*
The "where do my notes live" layer. All on-device, no backend.
- `project_screen` (auto-brief, task backlog, question pool, people, notes filtered)
- `inbox_screen` (swipe-right assign / swipe-left delete, batch)
- `person.dart` + `person_service` + `person_screen` (tap a name → everything about them)
- `graph.dart` + `graph_service` + `graph_painter` + `graph_screen` (Thought Graph: nodes=notes, edges=shared tags/people, pixel constellation)
- Bottom nav (Home · Graph · Search · Settings) — pixel icons
**Demo:** browse projects, see the graph of your thinking, tap a person.

### ⬜ SESSION 3 — Real Brain (LLM upgrade)
Make Miko genuinely smart when online; stay rule-based offline.
- `embedding_service` (local embeddings — on-device MiniLM via ONNX, or hash-embed fallback) + cosine search
- `search_service` + `search_screen` — **Ask Your Notes** (Find=instant local; Ask=LLM synthesis w/ citations)
- `llm_client` + Cloudflare Worker `/process` route — upgrade intent + Miko + synthesis to Claude when a key/Worker URL is set
- `vocab_service` — personal vocabulary engine (improves transcription of names/jargon)
**You provide:** a Claude API key (we put it in the Worker, never the app).
**Demo:** "what are my open questions about X?" → cited answer.

### ⬜ SESSION 4 — Voice, for real (audio + Telegram)
- `audio_service` — record to .m4a file (package: `record`), silence trim, store path on Note
- `audio_scrubber` — playback synced under transcript
- Telegram bot (Worker `/telegram`) — send a voice note to the bot → full pipeline → structured reply. **This is the acquisition hook, built before WhatsApp.**
**You provide:** create a Telegram bot via @BotFather (2 min), give me the token.
**Demo:** voice-note Ramble from Telegram, get Miko's structured reply.

### ⬜ SESSION 5 — Cloud & Sync (optional, opt-in)
- Supabase project: auth (email + Google) + `notes`/`projects` tables w/ RLS
- `sync_service` — local-first, background push/pull, conflict = last-write-wins
- Settings: sign in, sync toggle, "local only" stays default
**You provide:** create a free Supabase project, give me the URL + anon key.
**Demo:** install on a 2nd device, sign in, notes appear.

### ⬜ SESSION 6 — Cross-Note Intelligence
The PRD's "$1M" depth layer, now that data + LLM exist.
- Contradiction engine (project-wide), Question Pool, Decision Log (per project)
- Weekly synthesis (auto for projects w/ 3+ new notes)
- Pattern detection across reflections, Momentum score
**Demo:** open a project → auto-brief + contradictions + decision log.

### ⬜ SESSION 7 — Polish & Store-Ready
- App icon (Miko 1024², adaptive), splash screen, real app name/version
- Empty states, error states, haptics, pixel-wipe transitions, perf pass
- Onboarding refinement (value in 90s), accessibility, dark-mode audit
- **Signed release**: generate upload keystore, build signed AAB
- Store assets: screenshots (Telegram reply hero), description, privacy policy
**You provide:** Google Play Developer account ($25 one-time).
**Demo:** signed AAB ready to upload.

### ⬜ SESSION 8 — Buffer / Launch
Beta fixes, RevenueCat (Free/Pro gating), TestFlight-equiv (internal testing track),
ProductHunt/landing assets. Then: **rest of week = refine features/aesthetics.**

---

## 5. WHAT *YOU* DO (external, can't be automated)

Do these JUST-IN-TIME (not all now) — I'll prompt you at the right session:

| When | Task | Time | Cost |
|---|---|---|---|
| S3 | Claude API key (console.anthropic.com) — paste to me, goes in Worker | 5 min | usage-based |
| S3 | Cloudflare account (free) for the Worker — I scaffold, you `wrangler login` | 10 min | free |
| S4 | Telegram bot via @BotFather → token | 2 min | free |
| S5 | Supabase project (free) → URL + anon key | 10 min | free |
| S7 | Google Play Developer account | 20 min | $25 once |
| wk2 | (optional) WhatsApp Business via WATI/Twilio | hours+verify | $ |
| wk2 | (optional) Apple Developer + a Mac for iOS | — | $99/yr |

**Nothing is needed from you for Session 2.** It's 100% local.

---

## 6. RISKS / HONEST CONSTRAINTS

- **On-device LLM** (truly offline smart formatting) is weak on phones → we use
  rule-based offline + cloud LLM online. Don't promise on-device GPT-quality.
- **iOS** is blocked without a Mac; code stays cross-platform so it's ready.
- **WhatsApp** verification is the one multi-day external dependency → week 2.
- **Speaker diarization** (multi-voice) is heavy → V2, not MVP.
- Keep state management light until a screen actually demands more.

---

*Architect: Opus 4.8. Workers: Haiku. Integrator/COO: Sonnet. Updated each session.*
