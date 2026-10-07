import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FavoritesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = FavoritesService();
    await service.load();
  });

  group('custom names', () {
    final pier = Station(
      id: 'pier',
      name: 'Springmaid Pier, Myrtle beach',
      latitude: 0,
      longitude: 0,
    );
    final bridge = Station(
      id: 'bridge',
      name: 'Combination Bridge',
      latitude: 0,
      longitude: 0,
    );

    setUp(() async {
      await service.toggle('pier');
      await service.toggle('bridge');
    });

    test('a favorite with no custom name shows the station name', () {
      expect(service.customName('pier'), isNull);
      expect(service.displayName(pier), 'Springmaid Pier, Myrtle beach');
    });

    test('renaming changes what is displayed, only for that location', () async {
      await service.rename(pier, 'The Beach');
      expect(service.customName('pier'), 'The Beach');
      expect(service.displayName(pier), 'The Beach');
      expect(service.displayName(bridge), 'Combination Bridge');
    });

    test('the name is trimmed', () async {
      await service.rename(pier, '   The Beach  ');
      expect(service.displayName(pier), 'The Beach');
    });

    test('a blank name goes back to the station name', () async {
      await service.rename(pier, 'The Beach');
      await service.rename(pier, '   ');
      expect(service.customName('pier'), isNull);
      expect(service.displayName(pier), 'Springmaid Pier, Myrtle beach');
    });

    test('null goes back to the station name too', () async {
      await service.rename(pier, 'The Beach');
      await service.rename(pier, null);
      expect(service.customName('pier'), isNull);
    });

    test("typing the station's own name is not stored as a custom name", () async {
      await service.rename(pier, 'The Beach');
      await service.rename(pier, 'Springmaid Pier, Myrtle beach');
      expect(service.customName('pier'), isNull);
    });

    test('a very long name is cut to the limit', () async {
      await service.rename(pier, 'x' * 100);
      expect(service.customName('pier')!.length, FavoritesService.maxNameLength);
    });

    test('a station that is not a favorite cannot be renamed', () async {
      final other = Station(id: 'other', name: 'Other', latitude: 0, longitude: 0);
      await service.rename(other, 'Nope');
      expect(service.customName('other'), isNull);
    });

    test('unstarring forgets the name', () async {
      await service.rename(pier, 'The Beach');
      await service.toggle('pier'); // unstar
      await service.toggle('pier'); // star again
      expect(service.customName('pier'), isNull);
    });

    test('reordering keeps each name with its location', () async {
      await service.rename(pier, 'The Beach');
      await service.reorder(0, 1);
      expect(service.ids, ['bridge', 'pier']);
      expect(service.displayName(pier), 'The Beach');
    });

    test('names survive a restart', () async {
      await service.rename(pier, 'The Beach');

      final reloaded = FavoritesService();
      await reloaded.load();
      expect(reloaded.displayName(pier), 'The Beach');
      expect(reloaded.customName('bridge'), isNull);
    });

    test('a name saved for a station that is no longer a favorite is ignored', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_station_ids': ['pier'],
        'favorite_station_names': '{"pier":"The Beach","gone":"Old Name"}',
      });
      final reloaded = FavoritesService();
      await reloaded.load();
      expect(reloaded.customName('pier'), 'The Beach');
      expect(reloaded.customName('gone'), isNull);
    });

    test('unreadable saved names are dropped without losing the favorites', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_station_ids': ['pier', 'bridge'],
        'favorite_station_names': 'this is not json',
      });
      final reloaded = FavoritesService();
      await reloaded.load();
      expect(reloaded.ids, ['pier', 'bridge']);
      expect(reloaded.customName('pier'), isNull);
    });

    test('listeners hear about a rename, but not about no change', () async {
      var calls = 0;
      service.addListener(() => calls++);

      await service.rename(pier, 'The Beach');
      expect(calls, 1);
      await service.rename(pier, 'The Beach'); // same name
      expect(calls, 1);
    });
  });

  group('remove and undo', () {
    setUp(() async {
      for (final id in ['a', 'b', 'c', 'd']) {
        await service.toggle(id);
      }
    });

    Station station(String id) =>
        Station(id: id, name: 'Station $id', latitude: 0, longitude: 0);

    test('removing takes it out of the list', () async {
      final removed = await service.remove('b');
      expect(removed, isNotNull);
      expect(service.ids, ['a', 'c', 'd']);
      expect(service.isFavorite('b'), isFalse);
    });

    test('removing something that is not a favorite returns null', () async {
      expect(await service.remove('zzz'), isNull);
      expect(service.ids, ['a', 'b', 'c', 'd']);
    });

    test('undo puts it back in the same place', () async {
      final removed = (await service.remove('b'))!;
      await service.restore(removed);
      expect(service.ids, ['a', 'b', 'c', 'd']);
    });

    test('undo works for the first and the last item', () async {
      final first = (await service.remove('a'))!;
      await service.restore(first);
      expect(service.ids, ['a', 'b', 'c', 'd']);

      final last = (await service.remove('d'))!;
      await service.restore(last);
      expect(service.ids, ['a', 'b', 'c', 'd']);
    });

    test('undo brings back the custom name too', () async {
      await service.rename(station('c'), 'The Beach');
      final removed = (await service.remove('c'))!;
      expect(service.customName('c'), isNull); // gone while removed

      await service.restore(removed);
      expect(service.displayName(station('c')), 'The Beach');
      expect(service.ids, ['a', 'b', 'c', 'd']);
    });

    test('undo does not go past the end if the list got shorter', () async {
      final removed = (await service.remove('d'))!; // was at index 3
      await service.remove('c');
      await service.remove('b');
      expect(service.ids, ['a']);

      await service.restore(removed);
      expect(service.ids, ['a', 'd']);
    });

    test('undo does nothing if it was starred again in the meantime', () async {
      final removed = (await service.remove('b'))!;
      await service.toggle('b'); // starred again, goes to the end
      await service.restore(removed);
      expect(service.ids, ['a', 'c', 'd', 'b']); // not duplicated
    });

    test('a removal and its undo are both saved', () async {
      final removed = (await service.remove('b'))!;
      var reloaded = FavoritesService();
      await reloaded.load();
      expect(reloaded.ids, ['a', 'c', 'd']);

      await service.restore(removed);
      reloaded = FavoritesService();
      await reloaded.load();
      expect(reloaded.ids, ['a', 'b', 'c', 'd']);
    });
  });

  test('new favorites are added to the end', () async {
    await service.toggle('a');
    await service.toggle('b');
    await service.toggle('c');
    expect(service.ids, ['a', 'b', 'c']);
  });

  test('toggling an existing favorite removes it', () async {
    await service.toggle('a');
    await service.toggle('b');
    await service.toggle('a');
    expect(service.ids, ['b']);
    expect(service.isFavorite('a'), isFalse);
  });

  group('reorder (newIndex is the final position)', () {
    setUp(() async {
      for (final id in ['a', 'b', 'c', 'd']) {
        await service.toggle(id);
      }
    });

    test('moving an item down', () async {
      await service.reorder(0, 2); // "a" ends up between "c" and "d"
      expect(service.ids, ['b', 'c', 'a', 'd']);
    });

    test('moving an item to the very end', () async {
      await service.reorder(0, 3);
      expect(service.ids, ['b', 'c', 'd', 'a']);
    });

    test('moving an item up', () async {
      await service.reorder(3, 1); // drag "d" to sit before "b"
      expect(service.ids, ['a', 'd', 'b', 'c']);
    });
  });

  test('order survives saving and loading', () async {
    await service.toggle('a');
    await service.toggle('b');
    await service.toggle('c');
    await service.reorder(2, 0);

    final reloaded = FavoritesService();
    await reloaded.load();
    expect(reloaded.ids, ['c', 'a', 'b']);
  });
}
