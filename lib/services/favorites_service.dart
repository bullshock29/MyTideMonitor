import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which stations the user has starred, in what order, and any
/// custom names they have given them.
///
/// Extends [ChangeNotifier], so any widget wrapped in a [ListenableBuilder]
/// rebuilds automatically when a favorite is added, removed, moved, or
/// renamed. Everything is stored on the device: an ordered list of station
/// IDs, and a map from station ID to custom name.
class FavoritesService extends ChangeNotifier {
  static const String _key = 'favorite_station_ids';
  static const String _namesKey = 'favorite_station_names';

  /// The longest name a user can give a location.
  static const int maxNameLength = 40;

  final List<String> _ids = [];
  final Map<String, String> _names = {};

  /// The favorited station IDs, in the user's chosen order.
  List<String> get ids => List.unmodifiable(_ids);

  /// Loads saved favorites. Call once at startup, before `runApp`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll((prefs.getStringList(_key) ?? const []).toSet());

    _names.clear();
    final savedNames = prefs.getString(_namesKey);
    if (savedNames != null) {
      try {
        final decoded = jsonDecode(savedNames) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          // Ignore a name for a station that is no longer a favorite.
          if (_ids.contains(entry.key) && entry.value is String) {
            _names[entry.key] = entry.value as String;
          }
        }
      } catch (_) {
        // Unreadable names are dropped; the stations keep their own names.
      }
    }
    notifyListeners();
  }

  bool isFavorite(String stationId) => _ids.contains(stationId);

  /// Stars a station (added to the end of the list) or unstars it. Unstarring
  /// also forgets any custom name it had.
  Future<void> toggle(String stationId) async {
    if (_ids.remove(stationId)) {
      _names.remove(stationId);
    } else {
      _ids.add(stationId);
    }
    await _changed();
  }

  /// Removes a favorite and returns what was removed, so [restore] can put it
  /// back exactly as it was (same place in the list, same custom name).
  /// Returns null if the station wasn't a favorite.
  Future<RemovedFavorite?> remove(String stationId) async {
    final index = _ids.indexOf(stationId);
    if (index < 0) return null;

    final removed = RemovedFavorite(
      id: stationId,
      index: index,
      customName: _names[stationId],
    );
    _ids.removeAt(index);
    _names.remove(stationId);
    await _changed();
    return removed;
  }

  /// Puts back a favorite that [remove] took away. Does nothing if the
  /// station has been starred again in the meantime.
  Future<void> restore(RemovedFavorite removed) async {
    if (_ids.contains(removed.id)) return;

    // The list may be shorter now, so don't go past its end.
    _ids.insert(math.min(removed.index, _ids.length), removed.id);
    if (removed.customName != null) _names[removed.id] = removed.customName!;
    await _changed();
  }

  /// The name the user gave this favorite, or null if it has none.
  String? customName(String stationId) => _names[stationId];

  /// What to call [station] on screen: the user's name for it if it has one,
  /// otherwise NOAA's name.
  String displayName(Station station) => _names[station.id] ?? station.name;

  /// Gives a favorite a custom name. A blank [name], or one that is the same
  /// as the station's own name, goes back to the station's name. Does
  /// nothing for a station that isn't a favorite.
  Future<void> rename(Station station, String? name) async {
    if (!_ids.contains(station.id)) return;

    var cleaned = (name ?? '').trim();
    if (cleaned.length > maxNameLength) {
      cleaned = cleaned.substring(0, maxNameLength).trim();
    }

    if (cleaned.isEmpty || cleaned == station.name) {
      if (_names.remove(station.id) == null) return; // nothing changed
    } else {
      if (_names[station.id] == cleaned) return;
      _names[station.id] = cleaned;
    }
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
    await prefs.setString(_namesKey, jsonEncode(_names));
  }
}

/// A favorite that was just removed, kept so "Undo" can put it back.
class RemovedFavorite {
  final String id;

  /// Where it was in the list.
  final int index;

  /// The name the user had given it, if any.
  final String? customName;

  RemovedFavorite({required this.id, required this.index, this.customName});
}

/// The one shared instance used across the app.
final favoritesService = FavoritesService();
