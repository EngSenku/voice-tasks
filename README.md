<div align="center">

# Voice Tasks

**I need it, so I build it.**

**Voice-first task planner for Android.**

Speak a messy sentence; the app turns it into clean, scheduled tasks, drops
them into your calendar, and follows up like a person.

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

---

## Why

I kept capturing to-dos in scattered notes and forgetting the *when*. Every
existing app expected me to type, tap a date picker, choose a time, pick a
category. So I built the app I wanted: **say it, and it just works it out.**

> "today I want to play and go to the store and tomorrow I'll clean the house and study"
> → 4 tasks: two today, two tomorrow.

## Features

| | |
|---|---|
| 🎙️ **Tap-to-talk capture** | One button. Tap to start, tap to stop. The transcript survives pauses instead of restarting. |
| 🧠 **Full extraction, not just transcription** | An LLM splits the sentence into tasks and resolves each one's **day, clock time, kind and duration** — including multi-day sentences. |
| 🗓️ **Smart scheduling** | Flexible tasks land on your lightest day at your best hour. Overlaps and packed days get a friendly *"Move it to Friday at 6 pm?"* prompt. |
| ⏰ **Human reminders** | A nudge at the right time, a follow-up 45 min later with **Done / Later / Drop**. After three postponements it asks if the task should be made smaller. |
| 📅 **Phone calendar** | Writes events to the device calendar (optional switch). |
| 🌙 **Evening check-in** | Speaks *"How did today go?"* and understands *"I did the invoice but didn't call the dentist."* |
| ☀️ **Morning briefing** | Reads your day aloud with the phone's text-to-speech. |
| 📓 **Voice diary** | Talk freely; only the sentences that express intent become tasks. |
| 🔥 **Streaks & patterns** | Streak counter and learned habits (*"you finish most tasks before noon"*). |
| ⚡ **Fast capture** | Long-press the app icon → **Record a task**. |

## How it works

```mermaid
flowchart LR
  A["You tap mic\nand speak"] --> B["On-device recognizer\n(Hold-to-talk, pause/resume)"]
  B --> C["Raw transcript"]
  C --> D["Cloud AI\nNemotron 3.5 Lightning 30B"]
  D --> E["Structured JSON tasks\n(title, date, time, kind, duration, unsure)"]
  E --> F["Validation & normalisation\nfixes vague cases"]
  F --> G["Smart scheduler\n(flexible → best day/hour)\n(conflicts → suggest move)"]
  G --> H["Save to on-device store"]
  H --> I["Phone calendar & reminders\n(nudges, follow-ups, actions)"]
  H --> J["Briefing & Evening check-in"]
```

### 1. Capture
You speak; the phone's built-in `speech_to_text` turns it into text. Holding the mic means it keeps going even if you pause (no restart). No audio is uploaded — only the final text.

### 2. Full extraction (AI)
The text goes to **NVIDIA NIM (Nemotron 3.5 Lightning 30B)**. The prompt includes **today's date and the current time** so it can resolve *"tomorrow", "next week", "at 6pm", "before 5"* correctly. It returns a strict JSON array:

```json
{
  "tasks": [
    { "title": "Call mom", "date": "2026-10-15", "time": "17:00", "kind": "fixed", "duration": 15, "unsure": false },
    { "title": "Study",    "date": null,          "time": null,   "kind": "flexible", "duration": 45, "unsure": false }
  ]
}
```

### 3. Validation & normalisation (safety)
Before anything is shown or scheduled, Dart cleans up the model's answer:

- **Time without day** → `today` if that time is still ahead, else `tomorrow`
- **Date present but `kind=flexible`** → becomes `fixed`
- **`kind=deadline` but no limit word (`before/by/until`)** → becomes `fixed`
- **Deadline has a real limit word** → kept as `deadline`
- **Past date** → flagged as `unsure` so you can quickly review
- **Duration** → clamped to a sensible range, duplicates removed

### 4. Planning & scheduling
- **Flexible** (`date=null`) → placed on your **lightest day** at your **best hour**
- **Fixed/Deadline** → checked against existing tasks; if there's an **overlap** or the day is **packed**, the app suggests moving it to an open slot
- **Review screen** → tap any task's mic to re-say it and fix it instantly

### 5. Deliver & remind
Tasks stay on the phone. You can optionally sync to the phone's calendar. The app nudges at the right time, follows up 45 minutes later with **Done / Later / Drop**, and handles the evening check-in and morning briefing.

See [`lib/services/ai.dart`](lib/services/ai.dart) for the full prompt and [`lib/services/cloud_ai.dart`](lib/services/cloud_ai.dart) for the API call.

## Requirements

- Flutter **3.44+** (Dart 3.3+)
- Android device or emulator with Google speech services
- An API key for an OpenAI-compatible endpoint (the default is
  [NVIDIA NIM](https://build.nvidia.com) — a key is created in a couple of minutes)

## Getting started

```bash
git clone https://github.com/EngSenku/voice-tasks.git
cd voice-tasks

# The key is never committed. Pass it at build time:
flutter run --dart-define=NVIDIA_API_KEY=nvapi-your-key-here
```

Or paste the key into the app: **AI settings** (tap the status line under the
mic) → *API key*. It is stored in `shared_preferences` on the device and can be
changed or rotated at any time.

### Release build

```bash
flutter build apk --release --split-per-abi \
  --dart-define=NVIDIA_API_KEY=nvapi-your-key-here
```

Install with:

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Configuration

| Setting | Default | Where |
|---|---|---|
| API key | *(empty)* | `--dart-define=NVIDIA_API_KEY=…` or **AI settings** |
| Model | `nvidia/nemotron-3.5-lightning-30b-a3b` | **AI settings** |
| Base URL | `https://integrate.api.nvidia.com/v1` | **AI settings** |

`String.fromEnvironment('NVIDIA_API_KEY')` keeps credentials out of the source
tree entirely — the app ships with an empty default and asks for a key.

## Privacy & security

- **No backend, no account.** Tasks are stored on the phone only.
- Voice is transcribed **on the device** by the system recognizer; only the
  resulting **text** is sent to the model to be structured.
- No API key is hard-coded in this repository. Supply it at build time or enter
  it on the device.

## Project structure

```
lib/
├── main.dart                 # entry point, quick actions, notification wiring
├── models/task.dart          # Task model, enums, date helpers
├── theme.dart                # dark "glass" theme
├── screens/                  # home, review, calendar, check-in
├── services/
│   ├── ai.dart               # ✦ prompt + JSON contract + normalisation
│   ├── cloud_ai.dart         # NVIDIA NIM client
│   ├── speech.dart           # recognizer with pause/resume merge
│   ├── scheduler.dart        # slot finding, conflicts, packing
│   ├── store.dart            # persistence + notification scheduling
│   ├── notifier.dart         # reminders, repeats, follow-ups
│   ├── calendar_sync.dart    # device calendar bridge
│   ├── checkin.dart          # "what did you actually finish?" parsing
│   ├── insights.dart         # streaks, best hour, briefing text
│   └── quotes.dart           # cached daily quote
└── widgets/                  # glass panels, mic button, quote card
```

## Testing

```bash
flutter analyze
flutter test
```

The suite covers the AI JSON contract and normalisation (dates, times, kinds,
de-duplication) and the speech-transcript merge logic — the two places where a
mistake is most visible to the user.

## Known limits

- English only.
- Reminders use inexact alarms, so they can arrive a few minutes late (this
  avoids Android's special exact-alarm permission).
- Speech quality depends on the phone's recognizer.
- Location reminders ("when I'm near the pharmacy") need geofencing and are not
  included yet.

## License

[MIT](LICENSE) © 2026 Mohamed Abbou
