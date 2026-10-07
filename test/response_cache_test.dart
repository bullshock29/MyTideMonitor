import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/services/response_cache.dart';

void main() {
  group('FileResponseCache (real files)', () {
    late Directory folder;
    late FileResponseCache cache;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('mtm_cache_test_');
      cache = FileResponseCache(directory: () async => folder);
    });

    tearDown(() async {
      if (await folder.exists()) await folder.delete(recursive: true);
    });

    test('what is saved can be read back, with when it was saved', () async {
      await cache.save('station-1', '{"a": 1}');

      final saved = await cache.read('station-1');
      expect(saved!.body, '{"a": 1}');
      expect(DateTime.now().difference(saved.savedAt).inSeconds, lessThan(5));
    });

    test('an unknown key reads as null', () async {
      expect(await cache.read('nothing-here'), isNull);
    });

    test('saving again replaces the old copy', () async {
      await cache.save('k', 'first');
      await cache.save('k', 'second');
      expect((await cache.read('k'))!.body, 'second');
    });

    test('different keys do not mix', () async {
      await cache.save('a', 'one');
      await cache.save('b', 'two');
      expect((await cache.read('a'))!.body, 'one');
      expect((await cache.read('b'))!.body, 'two');
    });

    test('the saved time is kept exactly', () async {
      final when = DateTime.utc(2026, 10, 6, 12, 30);
      await cache.save('k', 'x', savedAt: when);
      expect((await cache.read('k'))!.savedAt, when);
    });

    test('keys with characters that are not allowed in file names work', () async {
      await cache.save('marine-33.655_-78.918', 'waves');
      await cache.save('odd:key/with*chars?', 'odd');

      expect((await cache.read('marine-33.655_-78.918'))!.body, 'waves');
      expect((await cache.read('odd:key/with*chars?'))!.body, 'odd');
    });

    test('a damaged file reads as nothing instead of crashing', () async {
      await cache.save('k', 'fine');
      // Wreck the file behind the cache's back.
      for (final file in folder.listSync().whereType<File>()) {
        await file.writeAsString('not json at all');
      }
      expect(await cache.read('k'), isNull);
    });

    test('prune removes old entries and keeps recent ones', () async {
      await cache.save('old', 'x', savedAt: DateTime.now().subtract(const Duration(days: 20)));
      await cache.save('recent', 'y', savedAt: DateTime.now().subtract(const Duration(days: 2)));

      await cache.prune(const Duration(days: 14));

      expect(await cache.read('old'), isNull);
      expect((await cache.read('recent'))!.body, 'y');
    });

    test('prune also clears out files it cannot read', () async {
      await cache.save('good', 'x');
      await File('${folder.path}${Platform.pathSeparator}junk.json').writeAsString('???');

      await cache.prune(const Duration(days: 14));

      expect(folder.listSync().whereType<File>().length, 1);
      expect((await cache.read('good'))!.body, 'x');
    });

    test('prune does nothing, and does not fail, when the folder does not exist', () async {
      final missing = FileResponseCache(
        directory: () async => Directory('${folder.path}${Platform.pathSeparator}nope'),
      );
      await missing.prune(const Duration(days: 14));
    });

    test('a cache that cannot use its folder never throws', () async {
      // A "folder" that is really a file can't hold anything.
      final blocker = File('${folder.path}${Platform.pathSeparator}blocker');
      await blocker.writeAsString('i am a file');
      final broken = FileResponseCache(directory: () async => Directory(blocker.path));

      await broken.save('k', 'x'); // must not throw
      expect(await broken.read('k'), isNull);
    });
  });

  group('MemoryResponseCache', () {
    test('saves, reads and replaces', () async {
      final cache = MemoryResponseCache();
      expect(await cache.read('k'), isNull);

      await cache.save('k', 'one');
      expect((await cache.read('k'))!.body, 'one');

      await cache.save('k', 'two');
      expect((await cache.read('k'))!.body, 'two');
      expect(cache.length, 1);
    });

    test('prune removes old entries', () async {
      final cache = MemoryResponseCache();
      await cache.save('old', 'x', savedAt: DateTime.now().subtract(const Duration(days: 20)));
      await cache.save('new', 'y');

      await cache.prune(const Duration(days: 14));

      expect(await cache.read('old'), isNull);
      expect(await cache.read('new'), isNotNull);
    });
  });
}
