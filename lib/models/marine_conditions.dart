import 'package:my_tide_monitor/models/wave_conditions.dart';

/// What the sea is doing near a spot: the waves and the water temperature.
///
/// Either part can be missing on its own. The model has waves for Lake
/// Michigan but no water temperature, for example, and a temperature for some
/// bays where it has no waves.
class MarineConditions {
  final WaveConditions? waves;

  /// Sea surface temperature in degrees Celsius.
  final double? waterTemperatureCelsius;

  /// When this was loaded (or, for a saved copy, saved).
  final DateTime fetchedAt;

  /// True when there was no connection and this is a copy saved earlier. Unlike
  /// tide predictions, waves and temperature are forecasts that change, so a
  /// saved copy gets older and the screen should say so.
  final bool fromCache;

  MarineConditions({
    this.waves,
    this.waterTemperatureCelsius,
    DateTime? fetchedAt,
    this.fromCache = false,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  /// Reads an Open-Meteo marine API response that was requested with
  /// `current=wave_height,sea_surface_temperature`, `hourly=wave_height` and
  /// `length_unit=imperial` (which affects heights but not the temperature).
  ///
  /// Returns null when the response has neither waves nor a temperature,
  /// which is what inland places get. [fetchedAt] and [fromCache] say where
  /// the response came from.
  static MarineConditions? fromJson(
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
    bool fromCache = false,
  }) {
    final waves = WaveConditions.fromJson(json);
    final temperature =
        (json['current'] as Map<String, dynamic>?)?['sea_surface_temperature']
            as num?;

    if (waves == null && temperature == null) return null;
    return MarineConditions(
      waves: waves,
      waterTemperatureCelsius: temperature?.toDouble(),
      fetchedAt: fetchedAt,
      fromCache: fromCache,
    );
  }
}
