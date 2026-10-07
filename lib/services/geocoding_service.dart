import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:my_tide_monitor/models/place.dart';

/// Turns a place name into coordinates using the free Open-Meteo geocoding
/// API (no key needed).
class GeocodingService {
  static const String _host = 'geocoding-api.open-meteo.com';

  /// Places matching [query], best match first. Empty if nothing matches.
  ///
  /// The API matches on the place name only, so search "Cape May" rather
  /// than "Cape May, NJ".
  Future<List<Place>> search(String query) async {
    final uri = Uri.https(_host, '/v1/search', {
      'name': query,
      'count': '10',
      'language': 'en',
      'format': 'json',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Search returned status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // When nothing matches, the response has no "results" key at all.
    final results = body['results'] as List?;
    if (results == null) return [];

    return results
        .map((r) => Place.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
