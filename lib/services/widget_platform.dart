import 'package:flutter/services.dart';

/// The connection to the Android side of the home screen widget.
///
/// An interface, so the code that uses it can be tested without a phone; the
/// real one ([ChannelWidgetPlatform]) talks to Kotlin code in MainActivity.
abstract class WidgetPlatform {
  /// Hands the widget its data (a JSON string) and asks it to redraw.
  Future<void> saveSnapshot(String json);

  /// If the app was just opened by tapping a location in the widget, the ID of
  /// that station, once. Null if it wasn't opened that way.
  Future<String?> takeLaunchStationId();

  /// Calls [onTap] with a station ID when a location in the widget is tapped
  /// while the app is already running.
  void listenForStationTaps(void Function(String stationId) onTap);
}

class ChannelWidgetPlatform implements WidgetPlatform {
  static const MethodChannel _channel = MethodChannel('com.mtm.my_tide_monitor/widget');

  @override
  Future<void> saveSnapshot(String json) async {
    try {
      await _channel.invokeMethod<void>('saveSnapshot', json);
    } on MissingPluginException {
      // Not running on Android (or in a test): there's no widget to update.
    }
  }

  @override
  Future<String?> takeLaunchStationId() async {
    try {
      return await _channel.invokeMethod<String>('takeLaunchStationId');
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void listenForStationTaps(void Function(String stationId) onTap) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stationTapped') onTap(call.arguments as String);
    });
  }
}
