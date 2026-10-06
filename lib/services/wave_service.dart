import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:my_tide_monitor/models/wave_conditions.dart';

/// Gets open-water wave heights from the free Open-Meteo marine API (a
/// computer model of the ocean, not a measurement; it needs no key).
class WaveService {
  static const String _host = 'marine-api.open-meteo.com';

  /// Waves now and over the next 24 hours at ([latitude], [longitude]), in
  /// feet. Returns null when the model has no waves there (inland places,
  /// some bays). Throws if the request itself fails.
  ///
  /// The model snaps to its nearest ocean grid point, a few miles wide, so
  /// this describes the open water near the spot, not a sheltered creek or
  /// the surf at one particular beach.
  Future<WaveConditions?> getWaves(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/v1/marine', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'wave_height',
      'hourly': 'wave_height',
      'length_unit': 'imperial',
      'forecast_hours': '24',
      'timezone': 'GMT',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Wave data returned status ${response.statusCode}');
    }

    return WaveConditions.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
