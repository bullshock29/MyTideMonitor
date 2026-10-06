import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:my_tide_monitor/models/station.dart';
import 'package:path_provider/path_provider.dart';

/// Provides the list of NOAA tide stations.
///
/// The full list is ~3,500 stations, and it rarely changes. The first call
/// downloads it, trims it to the fields we need, and saves it to a JSON file
/// in the app's documents folder. Later calls read that file instead of the
/// network until it is older than [maxAge].
///
/// Cache file format:
/// `{"version": 2, "fetchedAt": "<ISO 8601 UTC>", "stations": [ {id, name, state, lat, lng, type, reference_id}, ... ]}`
class StationRepository {
  /// Bump this when the cache gains new fields, so older cache files are
  /// refreshed instead of being used with the new fields missing.
  /// 1 (no version field): no reference_id. 2: adds reference_id.
  static const int _cacheVersion = 2;

  static final Uri _stationsUrl = Uri.parse(
    'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json'
    '?type=tidepredictions',
  );
  static const String _cacheFileName = 'noaa_stations.json';

  /// How long the cache is trusted before we try to refresh it.
  static const Duration maxAge = Duration(days: 30);

  /// Returns the stations, from the cache when it is fresh enough.
  ///
  /// Pass [forceRefresh] to always download. If the download fails and an
  /// older cache exists, the older cache is returned instead of an error.
  Future<List<Station>> getStations({bool forceRefresh = false}) async {
    final cached = await _readCache();

    if (cached != null &&
        !forceRefresh &&
        cached.version == _cacheVersion &&
        !_isStale(cached.fetchedAt)) {
      return cached.stations;
    }

    try {
      final fresh = await _download();
      await _writeCache(fresh);
      return fresh;
    } catch (_) {
      if (cached != null) return cached.stations;
      rethrow;
    }
  }

  bool _isStale(DateTime fetchedAt) {
    return DateTime.now().toUtc().difference(fetchedAt) > maxAge;
  }

  Future<List<Station>> _download() async {
    final response = await http
        .get(_stationsUrl)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw HttpException('NOAA returned status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final stations = (body['stations'] as List)
        .map((s) => Station.fromJson(s as Map<String, dynamic>))
        .toList();
    stations.sort((a, b) => a.name.compareTo(b.name));
    return stations;
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_cacheFileName');
  }

  Future<void> _writeCache(List<Station> stations) async {
    final file = await _cacheFile();
    final json = jsonEncode({
      'version': _cacheVersion,
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
      'stations': stations.map((s) => s.toJson()).toList(),
    });
    await file.writeAsString(json);
  }

  /// Reads the cache file. Returns null if it is missing or unreadable, so a
  /// corrupt file just triggers a fresh download.
  Future<({int version, DateTime fetchedAt, List<Station> stations})?>
      _readCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final stations = (json['stations'] as List)
          .map((s) => Station.fromJson(s as Map<String, dynamic>))
          .toList();
      return (
        version: json['version'] as int? ?? 1, // version 1 had no such field
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        stations: stations,
      );
    } catch (_) {
      return null;
    }
  }
}
