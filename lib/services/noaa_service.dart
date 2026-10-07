import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_tide_monitor/models/fetched.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/tide_point.dart';
import 'package:my_tide_monitor/services/response_cache.dart';
import 'package:my_tide_monitor/services/tide_curve.dart';

/// Thrown when NOAA answers with an error instead of data.
class NoaaException implements Exception {
  final String message;
  NoaaException(this.message);

  @override
  String toString() => message;
}

/// What came back for one request: the JSON, and where it came from.
typedef _Loaded = ({
  Map<String, dynamic> body,
  DateTime fetchedAt,
  bool fromCache,
});

/// Talks to NOAA's CO-OPS data API.
///
/// Every successful answer is also saved on the phone. When there's no
/// connection, the saved copy is used instead, and the result says so. Tide
/// predictions are astronomical, so a saved copy stays correct for as long as
/// it covers the time being asked about.
class NoaaService {
  static const String _host = 'api.tidesandcurrents.noaa.gov';
  static final http.Client _defaultClient = http.Client();

  final http.Client _client;
  final ResponseCache _cache;

  /// [client] and [cache] are only passed in by tests, to fake the network
  /// and use a temporary folder.
  NoaaService({http.Client? client, ResponseCache? cache})
      : _client = client ?? _defaultClient,
        _cache = cache ?? responseCache;

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
    return (await fetchUpcomingHighLows(stationId)).value;
  }

  /// Like [getUpcomingHighLows], but also says when the answer was loaded and
  /// whether it came from a copy saved earlier because there was no
  /// connection.
  Future<Fetched<List<Prediction>>> fetchUpcomingHighLows(String stationId) async {
    final now = DateTime.now().toUtc();

    // Start at the beginning of today (UTC) and ask for 3 days.
    final loaded = await _load(
      _predictionsUri(stationId, begin: now, hours: 72, highLowOnly: true),
      'noaa-hilo-$stationId',
    );
    final upcoming = _parse(loaded.body).where((p) => p.time.isAfter(now)).toList();

    // A saved copy only helps while it still covers the future.
    if (loaded.fromCache && upcoming.isEmpty) {
      throw const HttpException(
        'The saved tide predictions have run out. Connect to the internet to '
        'refresh them.',
      );
    }
    return Fetched(upcoming, fetchedAt: loaded.fetchedAt, fromCache: loaded.fromCache);
  }

  /// The high and low tides from yesterday to [days] days ahead, for the home
  /// screen widget. The widget works out the tide height at any moment from
  /// these, so with two weeks of them it stays right without the app being
  /// opened, and without any network.
  ///
  /// The tide before now is included on purpose: the height right now is
  /// somewhere between the last high or low and the next one.
  Future<Fetched<List<Prediction>>> fetchHighLowsAhead(
    String stationId, {
    int days = 14,
  }) async {
    final begin = DateTime.now().toUtc().subtract(const Duration(days: 1));

    final loaded = await _load(
      _predictionsUri(stationId, begin: begin, hours: (days + 1) * 24, highLowOnly: true),
      'noaa-widget-hilo-$stationId',
    );
    return Fetched(
      _parse(loaded.body),
      fetchedAt: loaded.fetchedAt,
      fromCache: loaded.fromCache,
    );
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
        final loaded = await _load(
          _predictionsUri(station.id, begin: begin, hours: 72),
          'noaa-curve6-${station.id}',
        );
        return TideCurve(
          [for (final p in _parse(loaded.body)) TidePoint(p.time, p.value)],
          isEstimated: false,
          fetchedAt: loaded.fetchedAt,
          fromCache: loaded.fromCache,
        );
      } on NoaaException {
        // No 6-minute data for this station; use highs and lows below.
      }
    }

    final loaded = await _load(
      _predictionsUri(station.id, begin: begin, hours: 72, highLowOnly: true),
      'noaa-curvehilo-${station.id}',
    );
    final points = curveFromExtremes(_parse(loaded.body));
    if (points.isEmpty) {
      throw NoaaException('No tide predictions are available for this station.');
    }
    return TideCurve(
      points,
      isEstimated: true,
      fetchedAt: loaded.fetchedAt,
      fromCache: loaded.fromCache,
    );
  }

  /// The request for predictions for [stationId], starting at the UTC date of
  /// [begin] and running for [hours]. Heights are in feet above MLLW and times
  /// are UTC. [highLowOnly] asks for highs and lows instead of a point every
  /// 6 minutes.
  Uri _predictionsUri(
    String stationId, {
    required DateTime begin,
    required int hours,
    bool highLowOnly = false,
  }) {
    return Uri.https(_host, '/api/prod/datagetter', {
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
  }

  /// Asks NOAA, and saves a good answer under [cacheKey].
  ///
  /// If the request fails because of the network (no signal, a timeout, a
  /// server error), the answer saved last time is returned instead, marked
  /// as coming from the cache. If there's nothing saved, the original failure
  /// is thrown.
  ///
  /// An error that NOAA itself reports (like "this station has no
  /// predictions") is a real answer, not a connection problem, so it's thrown
  /// as a [NoaaException] and the saved copy is not used.
  Future<_Loaded> _load(Uri uri, String cacheKey) async {
    late Object networkFailure;

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      final body = _decode(response.body);

      // NOAA explains problems (like an unknown station) in a JSON "error"
      // object. Depending on the problem the HTTP status is 200 or 400.
      final error = body?['error'];
      if (error != null) {
        throw NoaaException((error['message'] as String).trim());
      }
      if (response.statusCode != 200 || body == null || body['predictions'] is! List) {
        throw HttpException('NOAA returned status ${response.statusCode}');
      }

      await _cache.save(cacheKey, response.body);
      return (body: body, fetchedAt: DateTime.now(), fromCache: false);
    } on NoaaException {
      rethrow;
    } catch (failure) {
      networkFailure = failure;
    }

    final saved = await _cache.read(cacheKey);
    final savedBody = saved == null ? null : _decode(saved.body);
    if (saved != null && savedBody != null && savedBody['predictions'] is List) {
      return (body: savedBody, fetchedAt: saved.savedAt, fromCache: true);
    }
    throw networkFailure;
  }

  Map<String, dynamic>? _decode(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // not JSON
    }
  }

  List<Prediction> _parse(Map<String, dynamic> body) {
    return (body['predictions'] as List)
        .map((p) => Prediction.fromJson(p as Map<String, dynamic>, isUtc: true))
        .toList();
  }
}
