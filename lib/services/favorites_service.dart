import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which stations the user has starred.
///
/// Extends [ChangeNotifier], so any widget wrapped in a [ListenableBuilder]
/// rebuilds automatically when a favorite is added or removed. The favorites
/// are stored on the device as a list of station IDs.
class FavoritesService extends ChangeNotifier {
  static const String _key = 'favorite_station_ids';

  final Set<String> _ids = {};

  /// Loads saved favorites. Call once at startup, before `runApp`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
    notifyListeners();
  }

  bool isFavorite(String stationId) => _ids.contains(stationId);

  Future<void> toggle(String stationId) async {
    if (!_ids.remove(stationId)) _ids.add(stationId);
    notifyListeners(); // update the UI right away, save in the background

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
  }
}

/// The one shared instance used across the app.
final favoritesService = FavoritesService();
