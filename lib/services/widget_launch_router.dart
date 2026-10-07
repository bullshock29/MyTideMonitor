import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/widget_platform.dart';

/// Opens a location's detail screen when it is tapped in the home screen
/// widget, whether the app was closed (the tap starts it) or already running
/// (the tap brings it forward).
class WidgetLaunchRouter {
  final WidgetPlatform _platform;
  final Future<List<Station>> Function() _loadStations;

  /// Shows the detail screen for a station. Passed in by the app, since it
  /// needs the app's navigator.
  final Future<void> Function(Station station) _openStation;

  WidgetLaunchRouter({
    required this._platform,
    required this._loadStations,
    required this._openStation,
  });

  /// Starts listening for taps, and handles the tap that started the app, if
  /// there was one. Call it once the app's first screen is showing.
  Future<void> start() async {
    _platform.listenForStationTaps(_open);

    final launchedFrom = await _platform.takeLaunchStationId();
    if (launchedFrom != null) await _open(launchedFrom);
  }

  Future<void> _open(String stationId) async {
    try {
      final stations = await _loadStations();
      final match = stations.where((s) => s.id == stationId).firstOrNull;
      // A station that's no longer in the list can't be shown; do nothing.
      if (match != null) await _openStation(match);
    } catch (_) {
      // If the stations can't be loaded, staying on the home screen is fine.
    }
  }
}
