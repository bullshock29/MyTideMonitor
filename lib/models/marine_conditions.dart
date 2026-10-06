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

  MarineConditions({this.waves, this.waterTemperatureCelsius});

  /// Reads an Open-Meteo marine API response that was requested with
  /// `current=wave_height,sea_surface_temperature`, `hourly=wave_height` and
  /// `length_unit=imperial` (which affects heights but not the temperature).
  ///
  /// Returns null when the response has neither waves nor a temperature,
  /// which is what inland places get.
  static MarineConditions? fromJson(Map<String, dynamic> json) {
    final waves = WaveConditions.fromJson(json);
    final temperature =
        (json['current'] as Map<String, dynamic>?)?['sea_surface_temperature']
            as num?;

    if (waves == null && temperature == null) return null;
    return MarineConditions(
      waves: waves,
      waterTemperatureCelsius: temperature?.toDouble(),
    );
  }
}
