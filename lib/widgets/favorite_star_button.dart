import 'package:flutter/material.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';

/// A star that adds a station to the home screen (filled) or removes it
/// (outline). It updates itself when the favorites change, wherever else
/// that happens.
class FavoriteStarButton extends StatelessWidget {
  final String stationId;

  /// The color of the filled star. Null uses the surrounding icon color,
  /// which suits an app bar where amber would clash.
  final Color? starredColor;

  const FavoriteStarButton({
    super.key,
    required this.stationId,
    this.starredColor = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favoritesService,
      builder: (context, _) {
        final isFavorite = favoritesService.isFavorite(stationId);
        return IconButton(
          icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          color: isFavorite ? starredColor : null,
          tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
          onPressed: () => favoritesService.toggle(stationId),
        );
      },
    );
  }
}
