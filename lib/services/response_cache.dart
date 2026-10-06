import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A response that was saved earlier, and when.
class CachedResponse {
  final String body;
  final DateTime savedAt;

  CachedResponse(this.body, this.savedAt);
}

/// Saves the text of successful network responses, so the app can show the
/// last thing it knew when there's no signal.
///
/// Nothing here ever throws: a cache that can't be read or written just
/// behaves as if it were empty, because a broken cache must never stop the
/// app from working.
abstract class ResponseCache {
  /// Saves [body] under [key], replacing what was there. [savedAt] defaults
  /// to now; it's a parameter so tests can save something "from long ago".
  Future<void> save(String key, String body, {DateTime? savedAt});

  /// What was saved under [key], or null if nothing was, or it can't be read.
  Future<CachedResponse?> read(String key);

  /// Deletes saved responses older than [maxAge], so the cache doesn't grow
  /// forever as the user looks at more and more stations.
  Future<void> prune(Duration maxAge);
}

/// The cache the app uses: one small file per response, in the app's own
/// storage on the phone.
class FileResponseCache implements ResponseCache {
  final Future<Directory> Function() _directory;

  /// [directory] says where to keep the files. It defaults to a folder in the
  /// app's own storage; tests pass a temporary folder.
  FileResponseCache({Future<Directory> Function()? directory})
      : _directory = directory ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}response_cache');
  }

  Future<File> _file(String key) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    // Keys like "marine-33.655_-78.918" may contain characters that aren't
    // valid in a file name.
    final safeName = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${directory.path}${Platform.pathSeparator}$safeName.json');
  }

  @override
  Future<void> save(String key, String body, {DateTime? savedAt}) async {
    try {
      final file = await _file(key);
      await file.writeAsString(jsonEncode({
        'savedAt': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'body': body,
      }));
    } catch (_) {
      // Not being able to save only means no offline copy later.
    }
  }

  @override
  Future<CachedResponse?> read(String key) async {
    try {
      final file = await _file(key);
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return CachedResponse(
        json['body'] as String,
        DateTime.parse(json['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> prune(Duration maxAge) async {
    try {
      final directory = await _directory();
      if (!await directory.exists()) return;

      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in directory.list()) {
        if (entity is File) {
          final saved = await read(
            entity.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), ''),
          );
          // Judge by when it was saved; a file that can't be read is junk.
          if (saved == null || saved.savedAt.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // Leftover files are harmless.
    }
  }
}

/// A cache that lives in memory and is gone when the app closes. Used by
/// tests, which can't use real storage.
class MemoryResponseCache implements ResponseCache {
  final Map<String, CachedResponse> _entries = {};

  @override
  Future<void> save(String key, String body, {DateTime? savedAt}) async {
    _entries[key] = CachedResponse(body, savedAt ?? DateTime.now());
  }

  @override
  Future<CachedResponse?> read(String key) async => _entries[key];

  @override
  Future<void> prune(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    _entries.removeWhere((_, entry) => entry.savedAt.isBefore(cutoff));
  }

  /// How many responses are saved. For tests.
  int get length => _entries.length;
}

/// The cache the app uses. Tests replace it with a [MemoryResponseCache].
ResponseCache responseCache = FileResponseCache();
