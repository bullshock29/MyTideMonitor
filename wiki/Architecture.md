# Architecture

A tour of the code for anyone who wants to read or change it. The app is Flutter/Dart; the home screen widgets are Android (Kotlin) and talk to the app over a small channel.

```
lib/
  main.dart                 start-up, the widget connection, MainApp
  models/                   plain data classes
  screens/                  one file per screen (screens/menu/ = menu pages)
  services/                 talking to the network, saving data, the logic
  widgets/                  reusable pieces of UI
  theme/app_theme.dart      Material 3 themes (light/dark x blue/green/orange)
android/app/src/main/
  kotlin/com/mtm/my_tide_monitor/   the home screen widgets
  res/                              widget layouts, drawables, strings
android/app/src/test/               Kotlin unit tests
test/                               Dart tests
tool/                               one-off tooling (icon generator)
assets/icon/                        icon and splash art
```

## The Dart app

### Layers
- **Screens** show things and react to taps. They hold very little logic.
- **Services** (`lib/services/`) do the work: network calls, saved data, and the decisions (which station, what size are the waves).
- **Models** (`lib/models/`) are simple data holders: `Station`, `Prediction`, `Place`, `TidePoint`, `MarineConditions`, `WaveConditions`, `Fetched<T>` and so on.

### State
Shared state lives in a few `ChangeNotifier` services, created once as globals:
- `favoritesService`: the saved locations, their order and custom names
- `settingsService`: units, time format, theme mode and color

`SettingsScope` (an `InheritedNotifier`) puts the settings above the whole app, so any screen can read `SettingsScope.of(context)` and rebuild when a setting changes. All unit and time formatting (`formatHeight`, `formatTemperature`, `formatClock`, ...) lives on `SettingsService`, so screens just ask for the text. The app keeps every measurement in one fixed unit internally (feet, miles, °C, UTC) and only converts for display.

### The important services
| File | Job |
|---|---|
| `noaa_service.dart` | NOAA predictions: upcoming highs/lows, the tide curve, two weeks of highs/lows for the widgets |
| `marine_service.dart` | Open-Meteo waves and water temperature |
| `geocoding_service.dart` | Place search by name |
| `location_service.dart` | The phone's current location (via `geolocator`) |
| `station_repository.dart` | The NOAA station list, cached on disk for 30 days |
| `station_locator.dart` | Distance maths and "nearest stations" ranking |
| `station_picker.dart` + `tide_comparison.dart` | Decide whether nearby stations agree (see [How It Works](How-It-Works#choosing-a-station)) |
| `tide_curve.dart` | The half-cosine curve between highs and lows |
| `station_hint.dart` | Guesses ocean / harbor / waterway from a station's name |
| `response_cache.dart` | Saves network answers for offline use |
| `favorites_service.dart`, `settings_service.dart` | Saved locations and settings (stored with `shared_preferences`) |

### Testing seams
Services take their collaborators as optional constructor arguments (an `http.Client`, a `ResponseCache`), so tests can swap in fakes. `ResponseCache` is an abstract class with a file-based `FileResponseCache` for the app and an in-memory `MemoryResponseCache` for widget tests (real file access hangs under a test's fake clock).

### Offline
`NoaaService` and `MarineService` save every good response. If a request fails because of the network, the saved copy is returned, wrapped in `Fetched<T>` with `fromCache: true` and the time it was saved, so screens can say how old it is. An error that NOAA itself reports (such as "no predictions for this station") is a real answer and is never replaced by a saved copy.

## The widgets
There are two widgets (`TideWidgetProvider` for the list, `TideTileProvider` for the tile). Android widgets are drawn from `RemoteViews`, a fixed list of simple views, from a separate process. They can't run Flutter, so the app **sends them data** and the Kotlin side does the drawing.

### Data flow
```
Dart app                                   Kotlin
--------                                   ------
WidgetSync  --JSON snapshot-->  MainActivity (MethodChannel)  -->  WidgetStore (SharedPreferences "tide_widget")
 (favorites, settings,                                               |
  NOAA highs/lows, Open-Meteo)                                       v
                                         TideWidgetProvider / TideTileProvider  --> RemoteViews
                                         (+ TideWidgetService for the list rows)
                                         WorkManager: redraw every 15 min
```
- `lib/services/widget_sync.dart` builds a **snapshot** whenever something the widgets show changes (a location added, removed, moved or renamed; a setting; the app starting or resuming) and sends it with `saveSnapshot`. Writes are debounced (600 ms), and it never throws, since the widget is a nicety.
- The snapshot (`lib/services/widget_snapshot.dart`, version 2) is JSON: the units and time format, light and dark **palettes** taken from the app's Material 3 theme, and for each saved location its name, about two weeks of high/low tides as `[time ms, feet, "H"|"L"]`, and optionally `marine: {waveFeet, waterCelsius, readAt}`.
- The snapshot says **nothing** about how an individual widget looks or which location it shows. That is per widget.
- The Kotlin side parses it (`WidgetSnapshot.kt`), works out "now" itself (`TideMath.kt`, the same half-cosine as the Dart code, cross-checked against it), formats the text (`WidgetFormat.kt`) and draws.

### Per-widget settings
`WidgetConfig` (appearance, opacity, location, text size) is saved per Android widget id in the same SharedPreferences file (`widget_<id>_...`) and removed when the widget is deleted. `WidgetConfigActivity` is the settings screen; Android opens it on add and on touch-and-hold (`android:configure` and `widgetFeatures="reconfigurable"` in the widget info XML). Its live preview is built by the same code as the real widget.

### The glass look
Three stacked images in each layout (`widget_bg`, `widget_sheen`, `widget_border`): a tinted fill, a soft light gradient and a thin edge. `WidgetGlass` tints them with `setColorFilter` and sets their transparency with `setImageAlpha`. One gotcha: a shape drawable that is only a stroke must contain `<solid android:color="#00000000"/>`, or tinting fills the whole shape.

### Light and dark
`setThemedColor` uses `setColorInt(viewId, method, lightColor, darkColor)` on Android 14+, so a widget set to follow the phone switches by itself. Older versions get the right color at the next redraw.

### Taps
A tap opens the deep link `mtm://station/<id>`. `MainActivity` declares an intent filter for that address (Android 17 refuses an explicit intent that matches no filter). On a cold start the id waits in `MainActivity` until Dart asks for it (`takeLaunchStationId`); when the app is already running it is pushed to Dart (`stationTapped`). `WidgetLaunchRouter` opens the detail screen.

### The channel
Channel name `com.mtm.my_tide_monitor/widget`:
- Dart to Kotlin: `saveSnapshot(json)`, `takeLaunchStationId()`
- Kotlin to Dart: `stationTapped(id)`

### Redrawing
`TideWidgetWorker` (WorkManager) refreshes every 15 minutes while any widget exists. Android's `updatePeriodMillis` is also set to 30 minutes. A redraw needs no network.

## Where to start reading
- The app's start: `lib/main.dart`
- A screen end to end: `lib/screens/station_detail_screen.dart`, then `lib/widgets/station_tides.dart`
- Station choice: `lib/services/station_picker.dart` and its tests
- The widgets: `TideTileProvider.kt`, then `WidgetFormat.kt`
