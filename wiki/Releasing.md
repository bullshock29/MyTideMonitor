# Releasing

## Version numbers
The version is one line in `pubspec.yaml`:

```yaml
version: 10.7.26+1
```

The part before the `+` is the **name** and the number after it is the **build number**. On Android these become:

| Android field | Comes from | Example | Used for |
|---|---|---|---|
| `versionCode` | the number after `+` | `1` | Android's comparison: a new install must have a **higher** `versionCode` than the installed app |
| `versionName` | name + `.` + build number | `10.7.26.1` | What people see (Settings, Apps, My Tide Monitor) |

The `versionName` is built in `android/app/build.gradle.kts`:
```kotlin
versionName = "${flutter.versionName}.${flutter.versionCode}"
```
If you would rather show just the name (`10.7.26`), change that line to `flutter.versionName`.

### The one rule
**The number after the `+` must always go up, and never reset.** Android ignores the date. If a later release has the same or a lower build number, phones will refuse to update to it. With a date-based name, keep counting:

```
10.7.26+1
10.8.26+2     (not +1)
11.2.26+3
```

## Building a release
```bash
flutter build apk --release
```
The file ends up at:

```
build/app/outputs/flutter-apk/app-release.apk
```
It is about 52 MB. To check what version is inside it, use the Android SDK's `aapt` (in `build-tools/<version>/`):

```powershell
aapt dump badging build\app\outputs\flutter-apk\app-release.apk | Select-String "^package:"
```
which prints `versionCode='...' versionName='...'`.

## Before you ship
1. `flutter analyze` and `flutter test` are clean.
2. The Kotlin tests pass (see [Building and Testing](Building-and-Testing#kotlin-widget-tests)).
3. `pubspec.yaml` has the new version, with a **higher build number**.
4. Everything is **committed, including new files**. In Android Studio, newly created files must be *added* to git before they appear in a commit; check that **Unversioned Files** is empty.
5. Install the release APK on a real phone and try the main paths: search, save, the detail screen, and a widget.

## Publishing on GitHub
1. Tag the commit that matches the build, for example `v10.7.26.1`, so the tag reads the same as the version on the phone.
2. Create a release from the tag.
3. Paste the release notes (what's new, known limits, credits).
4. Attach `app-release.apk`. Consider renaming it, for example `MyTideMonitor-10.7.26.1.apk`.

## Signing
The release build is currently signed with the **debug key** (`signingConfig = signingConfigs.getByName("debug")` in `android/app/build.gradle.kts`), which is the project's default and fine for installing on your own phone.

- A later build can only **update** an installed copy in place if it is signed with the **same key**. The debug key belongs to the computer that made it, so a build from a different machine won't update this one; it has to be uninstalled first.
- Putting the app on the Play Store would need a proper upload key and a signing setup, which has not been done.

## Installing a release
1. Download the `.apk` on the phone.
2. Open it. If Android asks, allow installs from that app (your browser or file manager).
3. Open **My Tide Monitor**, add a location, then add a widget.
