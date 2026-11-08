# ZEEP Breathe – iOS / Android (Flutter)

Mobile port of the desktop prototype in `../app` (Rust/egui), following
`../app/docs/FLUTTER_PLAN.md`. Same breathing engine, same Zeep character,
real haptics.

| Prototype (`app/src`) | Flutter (`lib/`)                                            |
|-----------------------|-------------------------------------------------------------|
| `engine.rs`           | `breathing/breathing_engine.dart` + `test/` (unit tests)    |
| `character.rs`        | `ui/zeep_character.dart` (CustomPainter, no Rive art needed) |
| `haptics.rs`          | `haptics/haptics_service.dart` → `ios/Runner/AppDelegate.swift` (Core Haptics), `MainActivity.kt` (VibrationEffect) |
| `audio.rs`            | `audio/music_service.dart` + `assets/audio/*.wav` rendered by `tool/render_audio.py` |
| `settings.rs`         | `settings/settings_controller.dart` (shared_preferences)    |
| `app.rs`              | `app_controller.dart`, `screens/`                           |

Mobile additions: screen stays awake during a session, the session pauses when
the app goes to the background, portrait only, reduce-motion turns off the
float/sway.

## Commands

```
flutter pub get
flutter test                                           # engine unit tests
flutter test tool/screens_test.dart --update-goldens   # iPhone-size screenshots → tool/screens/
flutter run                                            # on a connected device / simulator
```

## TestFlight

See [TESTFLIGHT.md](TESTFLIGHT.md) – cloud build via Codemagic, no Mac required.
Bundle ID: `com.pillarsnova.zeepBreathe`.
