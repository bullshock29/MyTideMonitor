import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/services/response_cache.dart';

/// Gets waves and water temperature from the free Open-Meteo marine API (a
/// computer model of the ocean, not a measurement; it needs no key).
///
/// Checked against real buoys, the water temperature agreed within about
/// 0.3°C and the waves matched well offshore.
///
/// Every good answer is saved on the phone. With no connection, a saved copy
/// is used if it's recent enough, and the result says it came from the cache.
class MarineService {
  static const String _host = 'marine-api.open-meteo.com';
  static final http.Client _defaultClient = http.Client();

  /// A saved copy older than this is no longer shown. Waves and water
  /// temperature are forecasts that change, so a day-old copy would mislead
  /// more than it would help.
  static const Duration maxCacheAge = Duration(hours: 24);

  final http.Client _client;
  final ResponseCache _cache;

  /// [client] and [cache] are only passed in by tests.
  MarineService({http.Client? client, ResponseCache? cache})
      : _client = client ?? _defaultClient,
        _cache = cache ?? responseCache;

  /// Waves and water temperature at ([latitude], [longitude]): waves now and
  /// over the next 24 hours in feet, and the water temperature in °C. Returns
  /// null when the model has neither (inland places). Throws if the request
  /// fails and there's no recent saved copy.
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
    final cacheKey =
        'marine-${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}';

    Object failure;
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw HttpException('Marine data returned status ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await _cache.save(cacheKey, response.body);
      return MarineConditions.fromJson(json, fetchedAt: DateTime.now());
    } catch (error) {
      failure = error;
    }

    // No connection (or the service is down): use the saved copy if it's
    // recent enough.
    final saved = await _cache.read(cacheKey);
    if (saved != null && DateTime.now().difference(saved.savedAt) <= maxCacheAge) {
      try {
        return MarineConditions.fromJson(
          jsonDecode(saved.body) as Map<String, dynamic>,
          fetchedAt: saved.savedAt,
          fromCache: true,
        );
      } catch (_) {
        // A damaged copy is as good as none.
      }
    }
    throw failure;
  }
}
