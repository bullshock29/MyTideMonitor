import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which stations the user has starred, and in what order.
///
/// Extends [ChangeNotifier], so any widget wrapped in a [ListenableBuilder]
/// rebuilds automatically when a favorite is added, removed, or moved. The
/// favorites are stored on the device as an ordered list of station IDs.
class FavoritesService extends ChangeNotifier {
  static const String _key = 'favorite_station_ids';

  final List<String> _ids = [];

  /// The favorited station IDs, in the user's chosen order.
  List<String> get ids => List.unmodifiable(_ids);

  /// Loads saved favorites. Call once at startup, before `runApp`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll((prefs.getStringList(_key) ?? const []).toSet());
    notifyListeners();
  }

  bool isFavorite(String stationId) => _ids.contains(stationId);

  /// Stars a station (added to the end of the list) or unstars it.
  Future<void> toggle(String stationId) async {
    if (!_ids.remove(stationId)) _ids.add(stationId);
    await _changed();
  }

  /// Moves a favorite from [oldIndex] to [newIndex].
  ///
  /// [newIndex] is the position the item should end up at, which is what
  /// Flutter's `ReorderableListView.onReorderItem` provides.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final id = _ids.removeAt(oldIndex);
    _ids.insert(newIndex, id);
    await _changed();
  }

  Future<void> _changed() async {
    notifyListeners(); // update the UI right away, save in the background

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids);
  }
}

/// The one shared instance used across the app.
final favoritesService = FavoritesService();
