import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_tide_monitor/models/prediction.dart';

/// Thrown when NOAA answers with an error instead of data.
class NoaaException implements Exception {
  final String message;
  NoaaException(this.message);

  @override
  String toString() => message;
}

/// Talks to NOAA's CO-OPS data API.
class NoaaService {
  static const String _host = 'api.tidesandcurrents.noaa.gov';

  /// Like [getUpcomingHighLows], but returns null instead of throwing.
  ///
  /// NOAA occasionally fails a request that works a moment later, so this
  /// tries twice. A station that still fails (some never have predictions)
  /// gives null, so one bad station doesn't break a screen full of them.
  Future<List<Prediction>?> tryGetUpcomingHighLows(String stationId) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return await getUpcomingHighLows(stationId);
      } catch (_) {
        if (attempt == 1) await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  /// The upcoming high and low tides for [stationId], soonest first.
  ///
  /// Times are returned in UTC; call `.toLocal()` to show them on the device.
  Future<List<Prediction>> getUpcomingHighLows(String stationId) async {
    final now = DateTime.now().toUtc();

    final uri = Uri.https(_host, '/api/prod/datagetter', {
      'product': 'predictions',
      'station': stationId,
      'datum': 'MLLW',
      'time_zone': 'gmt',
      'units': 'english',
      'format': 'json',
      'interval': 'hilo',
      // Start at the beginning of today (UTC) and ask for 3 days.
      'begin_date': DateFormat('yyyyMMdd').format(now),
      'range': '72',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Not JSON, handled below.
    }

    // NOAA explains problems (like an unknown station) in a JSON "error"
    // object. Depending on the problem the HTTP status is 200 or 400.
    final error = body?['error'];
    if (error != null) {
      throw NoaaException((error['message'] as String).trim());
    }
    if (response.statusCode != 200 || body == null) {
      throw HttpException('NOAA returned status ${response.statusCode}');
    }

    return (body['predictions'] as List)
        .map((p) => Prediction.fromJson(p as Map<String, dynamic>, isUtc: true))
        .where((p) => p.time.isAfter(now))
        .toList();
  }
}
