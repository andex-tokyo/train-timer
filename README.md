# Train Timer

「次の一本まで、あと何分？」

Train Timer is a Flutter MVP for quickly checking the next train from the Android home screen. The app keeps timetable parsing and next-departure logic in Dart, while Android draws a compact 2x2 widget with Jetpack Glance through `home_widget`.

## What is included

- Flutter / Dart / Riverpod / Material 3 app shell
- Feature-first folders for home, profiles, automation, timetable, and settings
- Independent TBL parser and next-departure calculator
- Offline sample timetable at `assets/timetable/sample.tbl`
- Profile cycling with 30-minute manual override
- Weekday morning, weekday evening, and weekend auto-switch rules
- Express mode countdown formatting
- Android 2x2 Glance widget
- Widget tap actions:
  - Main body: cycle profile
  - Bottom-right icon: toggle express mode
- Adaptive and monochrome launcher icon assets
- Parser and midnight-rollover tests

## Commands

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Notes

- Flutter SDK is fixed through `.tool-versions` to `3.44.0-stable`.
- Android currently targets compile SDK 36 and uses Glance `1.2.0-rc01` to avoid the Android 37/AGP 9.1 requirement from Glance `1.3.0-alpha01`.
- A thin Drift database entry point is present for the future offline store, while this MVP persists profiles and mode flags with SharedPreferences for speed.
- The widget receives already-formatted display data from Dart via `home_widget`; native Kotlin only renders and dispatches taps.
