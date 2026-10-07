# Building and Testing

## What you need installed
- **Flutter** (stable). The project was built with **3.47.6**, which brings Dart 3.13.x (`pubspec.yaml` asks for `sdk: ^3.13.5`). Put Flutter's `bin` folder on your `PATH`.
- **Android Studio**, with the Android SDK, the SDK command-line tools and build tools. Android Studio's bundled JDK (the `jbr` folder) is what Gradle uses.
- **Android NDK 28.2.13676358.** Gradle asks for exactly this version; install it from Android Studio, SDK Manager, SDK Tools ("Show Package Details").
- Accepted Android licenses: `flutter doctor --android-licenses`
- An **emulator or a phone** (USB debugging on) to run it on.

Run `flutter doctor` and fix anything it flags under Android. The "Visual Studio / Desktop C++" warning on Windows doesn't matter for an Android-only app.

## Get it running
```bash
git clone https://github.com/bullshock29/MyTideMonitor.git
cd MyTideMonitor
flutter pub get
flutter run
```
`flutter run` builds a debug app, installs it on the connected device or emulator and starts it. In Android Studio you can also press the green play button.

While it runs, `r` in the terminal hot-reloads code changes and `R` restarts the app.

> The first run needs the internet, to download the NOAA station list (about 3,500 stations). After that it's saved on the phone.

## Checking your work

### Analyzer and Dart tests
```bash
flutter analyze
flutter test
```
`flutter analyze` should report **No issues found**. `flutter test` runs everything in `test/`: the services (NOAA, Open-Meteo, station choice, the tide curve, caching, settings, favorites), some screens, and the widget data code.

### Kotlin (widget) tests
These are plain JUnit tests of the widget logic (tide maths, text formatting, parsing the snapshot, colors, per-widget settings). They don't need a device.

From the `android` folder, with `JAVA_HOME` pointing at Android Studio's bundled JDK:

PowerShell:
```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
cd android
.\gradlew.bat :app:testDebugUnitTest
```
macOS/Linux:
```bash
export JAVA_HOME=/path/to/android-studio/jbr
cd android
./gradlew :app:testDebugUnitTest
```
Results are written as XML under `build/app/test-results/testDebugUnitTest/`.

### A debug build
```bash
flutter build apk --debug
```
produces `build/app/outputs/flutter-apk/app-debug.apk`.

## Trying the widgets on an emulator
1. Start the app once with a location saved, so it sends the widgets their data.
2. On the home screen, touch and hold an empty spot, choose **Widgets**, search "tide", and add **Tide list** or **Tide tile**.
3. Android can't be told to redraw a widget from the command line. After changing widget code, reinstall the app (the green play button, or `adb install -r app-debug.apk`) and the widget redraws.
4. To see the light/dark switch, toggle the emulator's dark mode (Settings, or `adb shell cmd uimode night yes` / `no`).

## Changing the app icon or splash
The icon art is drawn from `assets/icon/logo_source.png` by a script:
```bash
flutter test tool/generate_app_icon_test.dart   # writes the PNG layers in assets/icon/
dart run flutter_launcher_icons                  # makes the Android icon files
dart run flutter_native_splash:create            # makes the splash screen
```
Edit the colors and wave shapes at the top of `tool/generate_app_icon_test.dart` to restyle the icon. (It is named like a test only so it can use Flutter's drawing tools; the normal `flutter test` doesn't run it.)

## Troubleshooting
- **`flutter` isn't recognized:** the Flutter `bin` folder isn't on `PATH`.
- **Gradle says the NDK is missing:** install NDK `28.2.13676358` in the SDK Manager.
- **Gradle can't find Java:** set `JAVA_HOME` to Android Studio's `jbr`.
- **Tests that read real files hang:** widget tests should use `MemoryResponseCache` (set `responseCache = MemoryResponseCache()`), not the file-based one.
