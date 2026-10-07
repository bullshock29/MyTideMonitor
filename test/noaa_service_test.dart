import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/noaa_service.dart';
import 'package:my_tide_monitor/services/response_cache.dart';

import 'helpers/fake_predictions.dart';

Station _station(String id, {String type = 'R'}) => Station(
      id: id,
      name: 'Station $id',
      latitude: 0,
      longitude: 0,
      type: type,
    );

void main() {
  late MemoryResponseCache cache;
  late List<Uri> requests;
  final now = DateTime.now().toUtc();

  /// A service whose "internet" is [respond], which sees every request.
  NoaaService service(Future<http.Response> Function(Uri uri) respond) {
    return NoaaService(
      cache: cache,
      client: MockClient((request) {
        requests.add(request.url);
        return respond(request.url);
      }),
    );
  }

  Future<http.Response> ok(String body) async => http.Response(body, 200);
  Future<http.Response> noSignal(Uri _) async => throw http.ClientException('No signal');

  setUp(() {
    cache = MemoryResponseCache();
    requests = [];
  });

  group('upcoming high and low tides', () {
    test('online: returns the tides, not marked as saved, and saves them', () async {
      final noaa = service((_) => ok(hiloResponse(now)));

      final result = await noaa.fetchUpcomingHighLows('8661070');

      expect(result.fromCache, isFalse);
      expect(result.value, isNotEmpty);
      expect(result.value.every((p) => p.time.isAfter(now)), isTrue);
      expect(cache.length, 1);
    });

    test('asks NOAA for the right station and for highs and lows', () async {
      final noaa = service((_) => ok(hiloResponse(now)));
      await noaa.fetchUpcomingHighLows('8661070');

      final query = requests.single.queryParameters;
      expect(query['station'], '8661070');
      expect(query['interval'], 'hilo');
      expect(query['time_zone'], 'gmt');
    });

    test('no signal: uses the copy saved earlier and says so', () async {
      await service((_) => ok(hiloResponse(now))).fetchUpcomingHighLows('8661070');

      final offline = await service(noSignal).fetchUpcomingHighLows('8661070');

      expect(offline.fromCache, isTrue);
      expect(offline.value, isNotEmpty);
      // When it was saved: just now, in this test.
      expect(DateTime.now().difference(offline.fetchedAt).inSeconds, lessThan(5));
    });

    test('a saved copy keeps the time it was saved, not the time it was used', () async {
      final longAgo = DateTime.now().subtract(const Duration(hours: 5));
      await cache.save('noaa-hilo-8661070', hiloResponse(now), savedAt: longAgo);

      final offline = await service(noSignal).fetchUpcomingHighLows('8661070');

      expect(offline.fromCache, isTrue);
      expect(offline.fetchedAt.difference(longAgo).inSeconds.abs(), lessThan(2));
    });

    test('no signal and nothing saved: fails', () async {
      expect(
        service(noSignal).fetchUpcomingHighLows('8661070'),
        throwsA(isA<http.ClientException>()),
      );
    });

    test("one station's saved copy is never used for another station", () async {
      await service((_) => ok(hiloResponse(now))).fetchUpcomingHighLows('8661070');

      expect(
        service(noSignal).fetchUpcomingHighLows('8665530'),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('a server error falls back to the saved copy', () async {
      await service((_) => ok(hiloResponse(now))).fetchUpcomingHighLows('8661070');

      final result = await service((_) async => http.Response('Oops', 500))
          .fetchUpcomingHighLows('8661070');
      expect(result.fromCache, isTrue);
    });

    test('a reply that is not JSON falls back to the saved copy', () async {
      await service((_) => ok(hiloResponse(now))).fetchUpcomingHighLows('8661070');

      final result = await service((_) => ok('<html>Captive portal</html>'))
          .fetchUpcomingHighLows('8661070');
      expect(result.fromCache, isTrue);
    });

    test('a bad reply is never saved over a good copy', () async {
      await service((_) => ok(hiloResponse(now))).fetchUpcomingHighLows('8661070');
      await service((_) => ok('<html>Captive portal</html>'))
          .fetchUpcomingHighLows('8661070');

      final offline = await service(noSignal).fetchUpcomingHighLows('8661070');
      expect(offline.value, isNotEmpty); // still the good one
    });

    test('NOAA saying "no predictions" is a real answer: no saved copy is used', () async {
      // A good copy exists...
      await cache.save('noaa-hilo-8660754', hiloResponse(now));

      // ...but NOAA now says the station has no predictions. That is not a
      // connection problem, so the old copy must not hide it.
      expect(
        service((_) async => http.Response(noaaErrorResponse, 400))
            .fetchUpcomingHighLows('8660754'),
        throwsA(isA<NoaaException>()),
      );
    });

    test('a saved copy whose tides are all in the past is not used', () async {
      final past = now.subtract(const Duration(days: 10));
      await cache.save(
        'noaa-hilo-8661070',
        hiloResponse(past, hoursBefore: 12, hoursAfter: 24),
      );

      expect(
        service(noSignal).fetchUpcomingHighLows('8661070'),
        throwsA(isA<HttpException>()),
      );
    });

    test('getUpcomingHighLows still returns just the list', () async {
      final tides = await service((_) => ok(hiloResponse(now))).getUpcomingHighLows('8661070');
      expect(tides, isNotEmpty);
    });
  });

  group('tides for the home screen widget', () {
    test('asks for yesterday through two weeks ahead, as highs and lows', () async {
      final noaa = service((_) => ok(hiloResponse(now, hoursAfter: 340)));
      await noaa.fetchHighLowsAhead('8661070');

      final query = requests.single.queryParameters;
      expect(query['station'], '8661070');
      expect(query['interval'], 'hilo');
      expect(query['range'], '360'); // 15 days: yesterday plus 14 ahead

      final yesterday = now.subtract(const Duration(days: 1));
      String two(int n) => n.toString().padLeft(2, '0');
      expect(query['begin_date'], '${yesterday.year}${two(yesterday.month)}${two(yesterday.day)}');
    });

    test('keeps the tides from before now, which the widget needs', () async {
      final noaa = service((_) => ok(hiloResponse(now, hoursBefore: 12)));

      final result = await noaa.fetchHighLowsAhead('8661070');

      expect(result.value.any((p) => p.time.isBefore(now)), isTrue);
      expect(result.value.any((p) => p.time.isAfter(now)), isTrue);
    });

    test('a different number of days changes the range', () async {
      final noaa = service((_) => ok(hiloResponse(now)));
      await noaa.fetchHighLowsAhead('8661070', days: 7);
      expect(requests.single.queryParameters['range'], '192'); // 8 days
    });

    test('with no signal, uses the saved copy', () async {
      await service((_) => ok(hiloResponse(now))).fetchHighLowsAhead('8661070');

      final offline = await service(noSignal).fetchHighLowsAhead('8661070');

      expect(offline.fromCache, isTrue);
      expect(offline.value, isNotEmpty);
    });

    test("it is saved apart from the app's own tide list", () async {
      await service((_) => ok(hiloResponse(now))).fetchHighLowsAhead('8661070');

      // The widget's long list must not stand in for the short list the
      // screens use, or the other way round.
      expect(service(noSignal).fetchUpcomingHighLows('8661070'), throwsA(isA<http.ClientException>()));
    });

    test('with no signal and nothing saved, fails', () async {
      expect(service(noSignal).fetchHighLowsAhead('8661070'), throwsA(isA<http.ClientException>()));
    });
  });

  group('tide curve', () {
    test('a reference station uses the 6-minute predictions', () async {
      final noaa = service((_) => ok(sixMinuteResponse(now)));

      final curve = await noaa.getTideCurve(_station('8661070'));

      expect(curve.isEstimated, isFalse);
      expect(curve.fromCache, isFalse);
      expect(curve.points.length, greaterThan(300));
      expect(requests.length, 1);
      expect(requests.single.queryParameters.containsKey('interval'), isFalse);
    });

    test('a subordinate station goes straight to highs and lows', () async {
      final noaa = service((_) => ok(hiloResponse(now)));

      final curve = await noaa.getTideCurve(_station('8660854', type: 'S'));

      expect(curve.isEstimated, isTrue);
      expect(requests.length, 1); // no wasted 6-minute attempt
      expect(requests.single.queryParameters['interval'], 'hilo');
    });

    test('a reference station with no 6-minute data falls back to highs and lows', () async {
      final noaa = service((uri) async {
        return uri.queryParameters['interval'] == 'hilo'
            ? http.Response(hiloResponse(now), 200)
            : http.Response(noaaErrorResponse, 400);
      });

      final curve = await noaa.getTideCurve(_station('8661070'));

      expect(curve.isEstimated, isTrue);
      expect(requests.length, 2);
    });

    test('no signal: draws the chart from the saved copy and says so', () async {
      await service((_) => ok(sixMinuteResponse(now))).getTideCurve(_station('8661070'));

      final offline = await service(noSignal).getTideCurve(_station('8661070'));

      expect(offline.fromCache, isTrue);
      expect(offline.isEstimated, isFalse);
      expect(offline.points, isNotEmpty);
    });

    test('no signal for a subordinate station uses its saved highs and lows', () async {
      final station = _station('8660854', type: 'S');
      await service((_) => ok(hiloResponse(now))).getTideCurve(station);

      final offline = await service(noSignal).getTideCurve(station);

      expect(offline.fromCache, isTrue);
      expect(offline.isEstimated, isTrue);
    });

    test('no signal and nothing saved: fails', () async {
      expect(
        service(noSignal).getTideCurve(_station('8661070')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test("the chart's saved copy and the tide list's saved copy are separate", () async {
      // Saving the chart's data must not stand in for the tide list's data:
      // they cover different stretches of time.
      await service((_) => ok(sixMinuteResponse(now))).getTideCurve(_station('8661070'));

      expect(
        service(noSignal).fetchUpcomingHighLows('8661070'),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
