# Train Timer

「次の一本まで、あと何分？」

Train Timer is a Flutter MVP for checking the next train quickly from the app and Android home screen. The app keeps timetable parsing, next-departure calculation, profiles, auto switching, and widget payload generation in Dart. Android is responsible for rendering the home-screen widget and scheduling lightweight refreshes.

## Current MVP

- Flutter / Dart / Riverpod / Material 3
- Android home-screen widget with `home_widget` + Jetpack Glance
- Compact dark widget optimized for small launcher cells
- Native Chronometer countdown for low-cost second updates
- Operation-ended display after the last train until one hour before the first train
- Profile selection for frequently used trains
- Auto switching by weekday/time rules
- Manual profile override for 30 minutes
- Editable TBL text per profile
- Settings export/import as JSON
- Widget preview image for Android widget picker
- Sample timetable at `assets/timetable/sample.tbl`

## App Screens

- Home: current departure countdown and up to 3 following trains
- Riding Trains: profile list, reorder, edit, delete, export/import
- Auto Switch: create/edit time-based profile switch rules

## Widget Behavior

- Shows station, destination, departure time, and countdown
- Uses OS Chronometer when a departure is active
- Does not use `setAlarmClock()`, so it should not affect Android bedtime/DND alarm behavior
- Schedules lightweight refreshes around departure time to move to the next train
- Keeps widget information intentionally limited; following-train details are app-only

## TBL Support

Supported definitions:

```text
C:快速;快;#4040FF
X:普通;無印;#000000
a:府中本町;府
b:西船橋;西
```

Supported day blocks:

```text
[MON][TUE][WED][THU][FRI]
[SAT][SUN][HOL]
```

Supported train tokens:

```text
Xa22
XaA22
```

`Xa22` means:

- `X`: train kind
- `a`: destination
- `22`: minute

`XaA22` also works. The extra `A` before the minute is treated as platform/note metadata and ignored for now.

Single-value metadata definitions such as the following are accepted and ignored:

```text
A:2番線発車
B:1番線発車
```

## Build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Debug APK:

```sh
flutter build apk --debug
```

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Notes

- Flutter SDK is pinned through `.tool-versions` to `3.44.0-stable`.
- Android currently targets compile SDK 36.
- Drift is included as a future offline database entry point, but the MVP persists profiles and settings with SharedPreferences.
- TBL import/download automation is not implemented yet. For now, create or copy TBL text externally and paste it into the profile editor.
