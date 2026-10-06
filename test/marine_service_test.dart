import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_tide_monitor/services/marine_service.dart';
import 'package:my_tide_monitor/services/response_cache.dart';

import 'helpers/fake_predictions.dart';

void main() {
  late MemoryResponseCache cache;

  MarineService service(Future<http.Response> Function() respond) {
    return MarineService(cache: cache, client: MockClient((_) => respond()));
  }

  Future<http.Response> ok(String body) async => http.Response(body, 200);
  Future<http.Response> noSignal() async => throw http.ClientException('No signal');

  const lat = 33.655;
  const lng = -78.918;
  const key = 'marine-33.655_-78.918';

  setUp(() => cache = MemoryResponseCache());

  test('online: returns waves and temperature, not marked as saved, and saves them', () async {
    final result = await service(() => ok(marineResponse())).getConditions(lat, lng);

    expect(result!.fromCache, isFalse);
    expect(result.waves!.nowFeet, 3.1);
    expect(result.waterTemperatureCelsius, 25.3);
    expect(cache.length, 1);
  });

  test('no signal: uses the saved copy and says when it was saved', () async {
    final saved = DateTime.now().subtract(const Duration(hours: 3));
    await cache.save(key, marineResponse(), savedAt: saved);

    final result = await service(noSignal).getConditions(lat, lng);

    expect(result!.fromCache, isTrue);
    expect(result.fetchedAt.difference(saved).inSeconds.abs(), lessThan(2));
    expect(result.waves!.nowFeet, 3.1);
  });

  test('no signal right after a good load uses that load', () async {
    await service(() => ok(marineResponse(waveFeet: 4.2))).getConditions(lat, lng);

    final result = await service(noSignal).getConditions(lat, lng);
    expect(result!.fromCache, isTrue);
    expect(result.waves!.nowFeet, 4.2);
  });

  test('a saved copy over 24 hours old is too old to show', () async {
    await cache.save(
      key,
      marineResponse(),
      savedAt: DateTime.now().subtract(const Duration(hours: 25)),
    );

    expect(service(noSignal).getConditions(lat, lng), throwsA(isA<http.ClientException>()));
  });

  test('a saved copy just under 24 hours old is still shown', () async {
    await cache.save(
      key,
      marineResponse(),
      savedAt: DateTime.now().subtract(const Duration(hours: 23, minutes: 50)),
    );

    final result = await service(noSignal).getConditions(lat, lng);
    expect(result!.fromCache, isTrue);
  });

  test('no signal and nothing saved: fails', () async {
    expect(service(noSignal).getConditions(lat, lng), throwsA(isA<http.ClientException>()));
  });

  test('a saved copy for one place is not used for another', () async {
    await service(() => ok(marineResponse())).getConditions(lat, lng);

    expect(service(noSignal).getConditions(41.88, -87.62), throwsA(isA<http.ClientException>()));
  });

  test('a server error falls back to the saved copy', () async {
    await cache.save(key, marineResponse());

    final result = await service(() async => http.Response('Oops', 503)).getConditions(lat, lng);
    expect(result!.fromCache, isTrue);
  });

  test('a damaged saved copy is treated as no copy', () async {
    await cache.save(key, 'this is not json');

    expect(service(noSignal).getConditions(lat, lng), throwsA(isA<http.ClientException>()));
  });

  test('places with neither waves nor temperature (inland) give null', () async {
    final result = await service(
      () => ok(marineResponse(waveFeet: null, waterCelsius: null)),
    ).getConditions(39.74, -104.99);

    expect(result, isNull);
  });

  test('waves without a temperature still work', () async {
    final result = await service(
      () => ok(marineResponse(waterCelsius: null)),
    ).getConditions(lat, lng);

    expect(result!.waves, isNotNull);
    expect(result.waterTemperatureCelsius, isNull);
  });
}
