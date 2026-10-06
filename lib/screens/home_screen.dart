import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/us_states.dart';
import 'package:my_tide_monitor/screens/menu/find_by_city_screen.dart';
import 'package:my_tide_monitor/screens/station_detail_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/station_repository.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';
import 'package:my_tide_monitor/widgets/station_tides.dart';
import 'package:my_tide_monitor/widgets/station_waves.dart';

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

  // True while the user is dragging cards into a new order.
  bool _reordering = false;

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

  void _startReordering() {
    HapticFeedback.mediumImpact();
    setState(() => _reordering = true);
  }

  void _stopReordering() => setState(() => _reordering = false);

  // The favorited stations, in the order the user arranged them.
  List<Station> _favoriteStations(List<Station> all) {
    final byId = {for (final s in all) s.id: s};
    return [
      for (final id in favoritesService.ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    // While reordering, the back button leaves reorder mode instead of the app.
    return PopScope(
      canPop: !_reordering,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopReordering();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_reordering ? 'Reorder locations' : 'My Tide Monitor'),
          actions: [
            if (_reordering)
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'Done',
                onPressed: _stopReordering,
              ),
          ],
        ),
        drawer: const AppDrawer(),
        floatingActionButton: _reordering
            ? null
            : FloatingActionButton(
                tooltip: 'Add a location',
                shape: const CircleBorder(),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FindByCityScreen()),
                ),
                child: const Icon(Icons.add),
              ),
        body: FutureBuilder<List<Station>>(
          future: _stations,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load stations.'));
            }

            // Rebuild when a favorite is added, removed, or moved.
            return ListenableBuilder(
              listenable: favoritesService,
              builder: (context, _) {
                final favorites = _favoriteStations(snapshot.data!);

                if (favorites.isEmpty) return const _EmptyState();

                return _reordering
                    ? _buildReorderList(favorites)
                    : _buildCardList(favorites);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardList(List<Station> favorites) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        // Extra room at the bottom so the + button never covers the last card.
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final station = favorites[index];
          // A long press anywhere on a card starts reordering.
          return GestureDetector(
            key: ValueKey('${station.id}-$_refreshCount'),
            onLongPress: _startReordering,
            child: _FavoriteStationCard(station: station),
          );
        },
      ),
    );
  }

  // In reorder mode the tall tide cards shrink to one line each, so many fit
  // on screen and are easy to drag past each other.
  Widget _buildReorderList(List<Station> favorites) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      buildDefaultDragHandles: false,
      itemCount: favorites.length,
      onReorderItem: favoritesService.reorder,
      itemBuilder: (context, index) {
        final station = favorites[index];
        final hasState = station.state != null && station.state!.isNotEmpty;
        return Card(
          key: ValueKey(station.id),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(station.name),
            subtitle: hasState ? Text(stateName(station.state!)) : null,
            // Dragging starts as soon as the handle is touched.
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteStationCard extends StatelessWidget {
  final Station station;

  const _FavoriteStationCard({required this.station});

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
            child: StationTides(
              stationId: station.id,
              upcomingLimit: 3,
              belowNextTides: StationWaves(station: station),
            ),
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
              'Tap the + button to find a location by name or with your '
              'current location, and its tides will show up here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
