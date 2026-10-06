import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/us_states.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/widgets/station_conditions.dart';
import 'package:my_tide_monitor/widgets/station_tides.dart';

class StationDetailScreen extends StatelessWidget {
  final Station station;

  const StationDetailScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final hasState = station.state != null && station.state!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(station.name),
        actions: [
          ListenableBuilder(
            listenable: favoritesService,
            builder: (context, _) {
              final isFavorite = favoritesService.isFavorite(station.id);
              return IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                onPressed: () => favoritesService.toggle(station.id),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            [
              if (hasState) stateName(station.state!),
              'Station ${station.id}',
            ].join(' • '),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${station.latitude.toStringAsFixed(3)}, '
            '${station.longitude.toStringAsFixed(3)}'
            '${station.type == 'R' ? ' • Reference station' : ''}'
            '${station.type == 'S' ? ' • Subordinate station' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          StationTides(
            stationId: station.id,
            // Under the "Next high" and "Next low" tiles: waves, then the
            // tide chart. The "Upcoming" list follows below them.
            belowNextTides: StationConditions(station: station),
          ),
        ],
      ),
    );
  }
}
