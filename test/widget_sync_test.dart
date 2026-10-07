import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/widget_launch_router.dart';
import 'package:my_tide_monitor/services/widget_platform.dart';
import 'package:my_tide_monitor/services/widget_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in for the Android side that just remembers what it was sent.
class FakeWidgetPlatform implements WidgetPlatform {
  final List<Map<String, dynamic>> snapshots = [];
  String? launchStationId;
  void Function(String stationId)? tapHandler;
  bool failOnSave = false;

  @override
  Future<void> saveSnapshot(String json) async {
    if (failOnSave) throw Exception('The widget is not available');
    snapshots.add(jsonDecode(json) as Map<String, dynamic>);
  }

  @override
  Future<String?> takeLaunchStationId() async {
    final id = launchStationId;
    launchStationId = null; // it can only be taken once
    return id;
  }

  @override
  void listenForStationTaps(void Function(String stationId) onTap) => tapHandler = onTap;
}

Station _station(String id, String name) =>
    Station(id: id, name: name, latitude: 0, longitude: 0);

Prediction _high(int hoursFromNow) => Prediction(
      time: DateTime.now().toUtc().add(Duration(hours: hoursFromNow)),
      value: 5.0,
      type: 'H',
    );

void main() {
  late FavoritesService favorites;
  late SettingsService settings;
  late FakeWidgetPlatform platform;

  final stations = [
    _station('pier', 'Springmaid Pier'),
    _station('bridge', 'Combination Bridge'),
    _station('creek', 'Cape Island Creek'),
  ];

  WidgetSync makeSync({
    Future<List<Prediction>> Function(String id)? loadExtremes,
    Future<MarineConditions?> Function(Station station)? loadMarine,
    Duration delay = const Duration(milliseconds: 20),
  }) {
    return WidgetSync(
      favorites: favorites,
      settings: settings,
      platform: platform,
      loadStations: () async => stations,
      loadExtremes: loadExtremes ?? (id) async => [_high(3)],
      loadMarine: loadMarine ?? (station) async => null,
      delay: delay,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    favorites = FavoritesService();
    settings = SettingsService();
    platform = FakeWidgetPlatform();
  });

  group('what gets sent', () {
    test('the saved locations, in order, with their tides', () async {
      await favorites.toggle('bridge');
      await favorites.toggle('pier');

      await makeSync().syncNow();

      final locations = platform.snapshots.single['locations'] as List;
      expect(locations.map((l) => l['id']), ['bridge', 'pier']);
      expect(locations.map((l) => l['name']), ['Combination Bridge', 'Springmaid Pier']);
      expect((locations.first['extremes'] as List).length, 1);
    });

    test("a location's custom name is what the widget shows", () async {
      await favorites.toggle('pier');
      await favorites.rename(stations[0], 'The Beach');

      await makeSync().syncNow();

      expect((platform.snapshots.single['locations'] as List).single['name'], 'The Beach');
    });

    test('with no saved locations the widget is told so, and the list is empty', () async {
      await makeSync().syncNow();
      expect(platform.snapshots.single['locations'], isEmpty);
    });

    test('a location whose tides cannot be loaded is still listed, without tides', () async {
      await favorites.toggle('pier');
      await favorites.toggle('bridge');

      await makeSync(loadExtremes: (id) async {
        if (id == 'pier') throw Exception('No connection and nothing saved');
        return [_high(3)];
      }).syncNow();

      final locations = platform.snapshots.single['locations'] as List;
      expect(locations.length, 2);
      expect(locations[0]['extremes'], isEmpty); // pier failed
      expect((locations[1]['extremes'] as List).length, 1); // bridge fine
    });

    test('a saved location that is not in the station list is skipped', () async {
      await favorites.toggle('pier');
      await favorites.toggle('retired-station');

      await makeSync().syncNow();

      expect((platform.snapshots.single['locations'] as List).map((l) => l['id']), ['pier']);
    });

    test("every location's tides are requested, all at the same time", () async {
      await favorites.toggle('pier');
      await favorites.toggle('bridge');
      await favorites.toggle('creek');
      final requested = <String>[];

      await makeSync(loadExtremes: (id) async {
        requested.add(id);
        return [];
      }).syncNow();

      expect(requested.toSet(), {'pier', 'bridge', 'creek'});
    });

    test('the settings go along', () async {
      await settings.setHeightUnit(HeightUnit.meters);
      await settings.setTemperatureUnit(TemperatureUnit.celsius);

      await makeSync().syncNow();

      expect(platform.snapshots.single['heightUnit'], 'meters');
      expect(platform.snapshots.single['temperatureUnit'], 'celsius');
    });
  });

  group('waves and water temperature', () {
    final marine = MarineConditions(
      waves: WaveConditions(nowFeet: 2.4, next24HoursMinFeet: 1.5, next24HoursMaxFeet: 3.0),
      waterTemperatureCelsius: 21.5,
      fetchedAt: DateTime.utc(2026, 10, 6, 12),
    );

    test('are sent for an ocean location', () async {
      await favorites.toggle('pier');

      await makeSync(loadMarine: (station) async => marine).syncNow();

      final sent = (platform.snapshots.single['locations'] as List).single['marine'];
      expect(sent['waveFeet'], 2.4);
      expect(sent['waterCelsius'], 21.5);
      expect(sent['readAt'], DateTime.utc(2026, 10, 6, 12).millisecondsSinceEpoch);
    });

    test('are left out for a location on a waterway, which is never even asked', () async {
      await favorites.toggle('bridge');
      await favorites.toggle('creek');
      final asked = <String>[];

      await makeSync(loadMarine: (station) async {
        asked.add(station.id);
        return marine;
      }).syncNow();

      final locations = platform.snapshots.single['locations'] as List;
      expect(locations.every((l) => !(l as Map).containsKey('marine')), isTrue);
      expect(asked, isEmpty);
    });

    test('a missing part is sent as null, so the widget can leave it out', () async {
      await favorites.toggle('pier');

      await makeSync(
        loadMarine: (station) async => MarineConditions(waterTemperatureCelsius: 18),
      ).syncNow();

      final sent = (platform.snapshots.single['locations'] as List).single['marine'];
      expect(sent['waveFeet'], isNull);
      expect(sent['waterCelsius'], 18);
    });

    test('that cannot be loaded leave the location in, with its tides', () async {
      await favorites.toggle('pier');

      await makeSync(loadMarine: (station) async => throw Exception('offline')).syncNow();

      final location = (platform.snapshots.single['locations'] as List).single as Map;
      expect(location.containsKey('marine'), isFalse);
      expect((location['extremes'] as List).length, 1);
    });

    test('nothing known for the place sends nothing', () async {
      await favorites.toggle('pier');

      await makeSync(loadMarine: (station) async => null).syncNow();

      expect((platform.snapshots.single['locations'] as List).single.containsKey('marine'), isFalse);
    });
  });

  group('when it sends', () {
    test('starting sends a first snapshot', () async {
      await favorites.toggle('pier');
      final sync = makeSync()..start();

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(platform.snapshots.length, 1);
      sync.dispose();
    });

    test('adding, removing, moving or renaming a location sends a new one', () async {
      final sync = makeSync()..start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final before = platform.snapshots.length;

      await favorites.toggle('pier'); // add
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(platform.snapshots.length, before + 1);

      await favorites.toggle('bridge'); // add another
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await favorites.reorder(0, 1); // move
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((platform.snapshots.last['locations'] as List).map((l) => l['id']), ['bridge', 'pier']);

      await favorites.rename(stations[0], 'The Beach'); // rename
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((platform.snapshots.last['locations'] as List).last['name'], 'The Beach');

      await favorites.remove('pier'); // remove
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect((platform.snapshots.last['locations'] as List).map((l) => l['id']), ['bridge']);
      sync.dispose();
    });

    test('changing a setting sends a new one', () async {
      final sync = makeSync()..start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final before = platform.snapshots.length;

      await settings.setAppColor(AppColor.orange);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(platform.snapshots.length, before + 1);
      sync.dispose();
    });

    test('many quick changes (reordering locations) send only the last', () async {
      await favorites.toggle('pier');
      await favorites.toggle('bridge');
      await favorites.toggle('creek');
      final sync = makeSync(delay: const Duration(milliseconds: 80))..start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final before = platform.snapshots.length;

      await favorites.reorder(0, 2);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await favorites.reorder(0, 2);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await favorites.reorder(0, 2);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(platform.snapshots.length, before + 1);
      sync.dispose();
    });

    test('after dispose, nothing more is sent', () async {
      final sync = makeSync()..start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final before = platform.snapshots.length;

      sync.dispose();
      await favorites.toggle('pier');
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(platform.snapshots.length, before);
    });

    test('starting twice does not double up', () async {
      final sync = makeSync()
        ..start()
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(platform.snapshots.length, 1);
      sync.dispose();
    });
  });

  group('when something goes wrong', () {
    test('a widget that cannot be updated never disturbs the app', () async {
      platform.failOnSave = true;
      await favorites.toggle('pier');

      await makeSync().syncNow(); // must not throw
    });

    test('stations that cannot be loaded never disturb the app', () async {
      await favorites.toggle('pier');
      final sync = WidgetSync(
        favorites: favorites,
        settings: settings,
        platform: platform,
        loadStations: () async => throw Exception('no stations'),
        loadExtremes: (_) async => [],
        loadMarine: (_) async => null,
      );

      await sync.syncNow(); // must not throw
      expect(platform.snapshots, isEmpty);
    });
  });

  group('tapping a location in the widget', () {
    late List<Station> opened;
    late WidgetLaunchRouter router;

    setUp(() {
      opened = [];
      router = WidgetLaunchRouter(
        platform: platform,
        loadStations: () async => stations,
        openStation: (station) async => opened.add(station),
      );
    });

    test('opens that location when the tap started the app', () async {
      platform.launchStationId = 'bridge';
      await router.start();
      expect(opened.map((s) => s.id), ['bridge']);
    });

    test('opens nothing when the app was started normally', () async {
      await router.start();
      expect(opened, isEmpty);
    });

    test('the starting tap is only acted on once', () async {
      platform.launchStationId = 'bridge';
      await router.start();
      await router.start();
      expect(opened.length, 1);
    });

    test('opens a location when tapped while the app is already running', () async {
      await router.start();

      platform.tapHandler!('creek');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(opened.map((s) => s.id), ['creek']);
    });

    test('a tap on a station that no longer exists does nothing', () async {
      platform.launchStationId = 'long-gone';
      await router.start();
      expect(opened, isEmpty);
    });

    test('a station list that cannot be loaded does nothing, and does not crash', () async {
      final failing = WidgetLaunchRouter(
        platform: platform,
        loadStations: () async => throw Exception('offline'),
        openStation: (station) async => opened.add(station),
      );
      platform.launchStationId = 'pier';

      await failing.start(); // must not throw
      expect(opened, isEmpty);
    });
  });
}
