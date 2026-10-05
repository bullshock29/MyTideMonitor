import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/us_states.dart';
import 'package:my_tide_monitor/screens/station_detail_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/station_repository.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';

/// A titled section of the station list.
class _StationGroup {
  final String title;
  final List<Station> stations;

  _StationGroup(this.title, this.stations);
}

class NoaaStationsScreen extends StatefulWidget {
  const NoaaStationsScreen({super.key});

  @override
  State<NoaaStationsScreen> createState() => _NoaaStationsScreenState();
}

class _NoaaStationsScreenState extends State<NoaaStationsScreen> {
  static const String _otherGroup = 'Other';

  final _repository = StationRepository();
  final _searchController = TextEditingController();
  late Future<List<Station>> _stations;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _stations = _repository.getStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Pull-to-refresh and the retry button both come through here.
  Future<void> _refresh() async {
    final future = _repository.getStations(forceRefresh: true);
    setState(() => _stations = future);
    await future.catchError((_) => <Station>[]);
  }

  // Every word typed must appear in the station's name, state (code or full
  // name), or ID, so "cape may nj" finds Cape May, NJ.
  List<Station> _filter(List<Station> stations) {
    final words = _query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return stations;

    return stations.where((s) {
      final state = s.state ?? '';
      final text = '${s.name} $state ${stateName(state)} ${s.id}'.toLowerCase();
      return words.every(text.contains);
    }).toList();
  }

  // Favorites first, then one group per state (A to Z), then stations
  // without a state. Starred stations also appear in their state's group.
  List<_StationGroup> _group(List<Station> stations) {
    final groups = <_StationGroup>[];

    final favorites =
        stations.where((s) => favoritesService.isFavorite(s.id)).toList();
    if (favorites.isNotEmpty) groups.add(_StationGroup('Favorites', favorites));

    final byState = <String, List<Station>>{};
    for (final s in stations) {
      final state = (s.state == null || s.state!.isEmpty) ? _otherGroup : s.state!;
      byState.putIfAbsent(state, () => []).add(s);
    }

    final keys = byState.keys.toList()
      ..sort((a, b) {
        if (a == _otherGroup) return 1; // "Other" always last
        if (b == _otherGroup) return -1;
        return stateName(a).compareTo(stateName(b));
      });
    for (final key in keys) {
      final title = key == _otherGroup ? key : stateName(key);
      groups.add(_StationGroup(title, byState[key]!));
    }

    return groups;
  }

  void _openDetail(Station station) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StationDetailScreen(station: station)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('NOAA Stations'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search name, state, or ID',
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<Station>>(
      future: _stations,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load stations.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        final filtered = _filter(snapshot.data!);
        if (filtered.isEmpty) {
          return const Center(child: Text('No stations match your search.'));
        }

        // Rebuild the groups whenever a favorite is starred or unstarred.
        return ListenableBuilder(
          listenable: favoritesService,
          builder: (context, _) => _buildGroupedList(_group(filtered)),
        );
      },
    );
  }

  Widget _buildGroupedList(List<_StationGroup> groups) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Scrollbar(
        interactive: true,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            for (final group in groups)
              // A group is its pinned header plus its rows. The header stays
              // at the top until the next group's header pushes it off.
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _GroupHeaderDelegate(group),
                  ),
                  SliverList.builder(
                    itemCount: group.stations.length,
                    itemBuilder: (context, index) {
                      final station = group.stations[index];
                      return _StationTile(
                        station: station,
                        onTap: () => _openDetail(station),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Draws a group's header. A pinned [SliverPersistentHeader] needs a fixed
/// height, so every header is [_height] tall.
class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _height = 40;

  final _StationGroup group;

  _GroupHeaderDelegate(this.group);

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      alignment: Alignment.centerLeft,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '${group.title} (${group.stations.length})',
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  bool shouldRebuild(_GroupHeaderDelegate oldDelegate) {
    return oldDelegate.group != group;
  }
}

class _StationTile extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;

  const _StationTile({required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFavorite = favoritesService.isFavorite(station.id);
    return ListTile(
      title: Text(station.name),
      subtitle: Text('ID ${station.id}'),
      trailing: IconButton(
        icon: Icon(isFavorite ? Icons.star : Icons.star_border),
        color: isFavorite ? Colors.amber : null,
        tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
        onPressed: () => favoritesService.toggle(station.id),
      ),
      onTap: onTap,
    );
  }
}
