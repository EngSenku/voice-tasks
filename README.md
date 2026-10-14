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
