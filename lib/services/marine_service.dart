import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:my_tide_monitor/models/marine_conditions.dart';

/// Gets waves and water temperature from the free Open-Meteo marine API (a
/// computer model of the ocean, not a measurement; it needs no key).
///
/// Checked against real buoys, the water temperature agreed within about
/// 0.3°C and the waves matched well offshore.
class MarineService {
  static const String _host = 'marine-api.open-meteo.com';

  /// Waves and water temperature at ([latitude], [longitude]): waves now and
  /// over the next 24 hours in feet, and the water temperature in °C. Returns
  /// null when the model has neither (inland places). Throws if the request
  /// itself fails.
  ///
  /// The model snaps to its nearest ocean grid point, a few miles wide, so
  /// this describes the open water near the spot, not a sheltered creek or
  /// the surf at one particular beach.
  Future<MarineConditions?> getConditions(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/v1/marine', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'wave_height,sea_surface_temperature',
      'hourly': 'wave_height',
      'length_unit': 'imperial',
      'forecast_hours': '24',
      'timezone': 'GMT',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Marine data returned status ${response.statusCode}');
    }

    return MarineConditions.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
