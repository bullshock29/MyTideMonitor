import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FavoritesService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = FavoritesService();
    await service.load();
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
