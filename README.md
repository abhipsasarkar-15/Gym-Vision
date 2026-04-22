# cult_vision_kiosk_flutter

Cult Vision Flutter native prototype for kiosk recording, in-workout coaching, and shareable result flows.

## Run with Gemini voice coaching

The workout coach now supports Gemini-generated spoken cues. The API key is intentionally not stored in source.

Example local build:

```bash
flutter build macos \
  --dart-define=GEMINI_API_KEY=YOUR_KEY \
  --dart-define=GEMINI_MODEL=gemini-2.5-flash
```

Example local run:

```bash
flutter run -d macos \
  --dart-define=GEMINI_API_KEY=YOUR_KEY \
  --dart-define=GEMINI_MODEL=gemini-2.5-flash
```

Notes:

- The current default Gemini model in code is `gemini-2.5-flash`.
- Voice output is spoken natively by the device on macOS.
- The API key should be passed at runtime and never committed.
