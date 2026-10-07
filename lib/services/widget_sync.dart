import 'dart:async';
import 'dart:convert';

import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/station_hint.dart';
import 'package:my_tide_monitor/services/widget_platform.dart';
import 'package:my_tide_monitor/services/widget_snapshot.dart';

/// Keeps the home screen widgets up to date with the saved locations and the
/// settings.
///
/// It sends the widgets a fresh snapshot (see [buildWidgetSnapshot]) whenever
/// something they show changes: a location is added, removed, moved or
/// renamed, or a setting like the units or theme color changes. It also does
/// so when the app starts and each time it comes back to the screen, which is
/// when the tide data for the next two weeks, and the waves and water
/// temperature, are refreshed.
class WidgetSync {
  final FavoritesService _favorites;
  final SettingsService _settings;
  final WidgetPlatform _platform;

  /// All known stations, to find each favorite's coordinates and details.
  final Future<List<Station>> Function() _loadStations;

  /// The high and low tides for a station, from yesterday to two weeks ahead.
  /// Throws if they can't be had (no connection and nothing saved).
  final Future<List<Prediction>> Function(String stationId) _loadExtremes;

  /// The waves and water temperature near a station. May return null (nothing
  /// known) or throw (couldn't be loaded); either way the widget just leaves
  /// them out.
  final Future<MarineConditions?> Function(Station station) _loadMarine;

  final DateTime Function() _clock;
  final Duration _delay;

  Timer? _pending;
  bool _started = false;

  /// [delay] is how long to wait for changes to settle before sending, so a
  /// burst of changes (reordering locations, say) becomes one update.
  WidgetSync({
    required this._favorites,
    required this._settings,
    required this._platform,
    required this._loadStations,
    required this._loadExtremes,
    required this._loadMarine,
    DateTime Function()? clock,
    this._delay = const Duration(milliseconds: 600),
  }) : _clock = clock ?? DateTime.now;

  /// Starts watching for changes, and sends the first snapshot.
  void start() {
    if (_started) return;
    _started = true;
    _favorites.addListener(schedule);
    _settings.addListener(schedule);
    schedule();
  }

  void dispose() {
    _favorites.removeListener(schedule);
    _settings.removeListener(schedule);
    _pending?.cancel();
    _started = false;
  }

  /// Sends a snapshot soon. Many calls close together become one.
  void schedule() {
    _pending?.cancel();
    _pending = Timer(_delay, () => unawaited(syncNow()));
  }

  /// Builds and sends the snapshot right now.
  Future<void> syncNow() async {
    try {
      final locations = await _buildLocations();
      final snapshot = buildWidgetSnapshot(
        locations: locations,
        settings: _settings,
        generatedAt: _clock(),
      );
      await _platform.saveSnapshot(jsonEncode(snapshot));
    } catch (_) {
      // The widget is a nicety. Not being able to update it must never
      // disturb the app, and it keeps showing what it had.
    }
  }

  Future<List<WidgetLocation>> _buildLocations() async {
    final ids = _favorites.ids;
    if (ids.isEmpty) return [];

    final stations = {for (final s in await _loadStations()) s.id: s};

    // Load every station's tides at once; a station that fails just has none,
    // and the widget says to open the app for it.
    final locations = await Future.wait([
      for (final id in ids)
        if (stations[id] != null) _locationFor(stations[id]!),
    ]);
    return locations;
  }

  Future<WidgetLocation> _locationFor(Station station) async {
    List<Prediction> extremes;
    try {
      extremes = await _loadExtremes(station.id);
    } catch (_) {
      extremes = [];
    }

    // Waves and water temperature describe the open water, so they would
    // mislead for a station on a waterway (the same rule the home screen uses).
    MarineConditions? marine;
    if (guessSetting(station.name) != StationSetting.waterway) {
      try {
        marine = await _loadMarine(station);
      } catch (_) {
        marine = null;
      }
    }

    return WidgetLocation(
      id: station.id,
      name: _favorites.displayName(station),
      extremes: extremes,
      marine: marine,
    );
  }
}
