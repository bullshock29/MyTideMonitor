import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/tide_point.dart';
import 'package:my_tide_monitor/services/tide_curve.dart';

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

    // Start at the beginning of today (UTC) and ask for 3 days.
    final predictions = await _fetchPredictions(
      stationId,
      begin: now,
      hours: 72,
      highLowOnly: true,
    );
    return predictions.where((p) => p.time.isAfter(now)).toList();
  }

  /// A tide curve for [station] from 6 hours ago to 24 hours ahead (a little
  /// more on each side), good for drawing a chart and finding the height now.
  ///
  /// NOAA publishes a smooth prediction every 6 minutes for reference
  /// stations, and that is used when available. Subordinate stations only get
  /// highs and lows, so for those the curve is drawn between them (see
  /// [curveFromExtremes]) and the result is marked as estimated.
  Future<TideCurve> getTideCurve(Station station) async {
    // Start of yesterday (UTC) for 72 hours covers everything we need.
    final begin = DateTime.now().toUtc().subtract(const Duration(days: 1));

    if (!station.isSubordinate) {
      try {
        final points = await _fetchPredictions(
          station.id,
          begin: begin,
          hours: 72,
        );
        return TideCurve(
          [for (final p in points) TidePoint(p.time, p.value)],
          isEstimated: false,
        );
      } on NoaaException {
        // No 6-minute data for this station; use highs and lows below.
      }
    }

    final extremes = await _fetchPredictions(
      station.id,
      begin: begin,
      hours: 72,
      highLowOnly: true,
    );
    final points = curveFromExtremes(extremes);
    if (points.isEmpty) {
      throw NoaaException('No tide predictions are available for this station.');
    }
    return TideCurve(points, isEstimated: true);
  }

  /// Fetches predictions for [stationId], starting at the UTC date of
  /// [begin] and running for [hours]. Heights are in feet above MLLW and
  /// times are UTC. [highLowOnly] asks for highs and lows instead of a point
  /// every 6 minutes.
  Future<List<Prediction>> _fetchPredictions(
    String stationId, {
    required DateTime begin,
    required int hours,
    bool highLowOnly = false,
  }) async {
    final uri = Uri.https(_host, '/api/prod/datagetter', {
      'product': 'predictions',
      'station': stationId,
      'datum': 'MLLW',
      'time_zone': 'gmt',
      'units': 'english',
      'format': 'json',
      if (highLowOnly) 'interval': 'hilo',
      'begin_date': DateFormat('yyyyMMdd').format(begin.toUtc()),
      'range': '$hours',
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
        .toList();
  }
}
