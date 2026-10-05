import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/us_states.dart';
import 'package:my_tide_monitor/screens/station_detail_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/station_repository.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';
import 'package:my_tide_monitor/widgets/station_tides.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = StationRepository();
  late Future<List<Station>> _stations;

  // Changing this changes each card's key, which rebuilds the cards and
  // makes them fetch fresh tide times (used by pull-to-refresh).
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    _stations = _repository.getStations();
  }

  Future<void> _refresh() async {
    setState(() => _refreshCount++);
    // Let the pull-to-refresh spinner show briefly; the cards show their own.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tide Monitor')),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<Station>>(
        future: _stations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load stations.'));
          }

          // Rebuild when a favorite is added or removed.
          return ListenableBuilder(
            listenable: favoritesService,
            builder: (context, _) {
              final favorites = snapshot.data!
                  .where((s) => favoritesService.isFavorite(s.id))
                  .toList();

              if (favorites.isEmpty) return const _EmptyState();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final station = favorites[index];
                    return _FavoriteStationCard(
                      key: ValueKey('${station.id}-$_refreshCount'),
                      station: station,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteStationCard extends StatelessWidget {
  final Station station;

  const _FavoriteStationCard({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final hasState = station.state != null && station.state!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(station.name),
            subtitle: Text(
              [
                if (hasState) stateName(station.state!),
                'Station ${station.id}',
              ].join(' • '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StationDetailScreen(station: station),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StationTides(stationId: station.id, upcomingLimit: 3),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_border, size: 48),
            const SizedBox(height: 16),
            Text(
              'No favorite stations yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Open the menu, choose NOAA Stations, and tap the star on '
              'a station to see its tides here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
