import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/place.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/screens/station_detail_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/noaa_service.dart';
import 'package:my_tide_monitor/services/station_hint.dart';
import 'package:my_tide_monitor/services/station_locator.dart';
import 'package:my_tide_monitor/services/station_repository.dart';
import 'package:my_tide_monitor/services/tide_comparison.dart';
import 'package:my_tide_monitor/services/tide_format.dart';
import 'package:my_tide_monitor/widgets/home_button.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';

/// Upcoming tides for one station. Null when they couldn't be loaded.
typedef _Tides = Future<List<Prediction>?>;

/// Everything the screen needs once the stations are found:
/// - the nearby stations, best first
/// - every station by ID, so an estimated station can name its reference
/// - each nearby station's upcoming tides, still loading
typedef _NearbyResult = ({
  List<NearbyStation> nearby,
  Map<String, Station> stationsById,
  Map<String, _Tides> tidesById,
});

/// The best tide stations for a [Place], best match first.
class NearbyStationsScreen extends StatefulWidget {
  final Place place;

  const NearbyStationsScreen({super.key, required this.place});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  static const double _maxMiles = 50;

  final _noaa = NoaaService();
  late Future<_NearbyResult> _result;

  @override
  void initState() {
    super.initState();
    _result = _findNearby();
  }

  Future<_NearbyResult> _findNearby() async {
    final stations = await StationRepository().getStations();
    final nearby = nearestStations(
      stations,
      latitude: widget.place.latitude,
      longitude: widget.place.longitude,
      maxMiles: _maxMiles,
    );
    return (
      nearby: nearby,
      stationsById: {for (final s in stations) s.id: s},
      // Start every station's tide request now, all at once. The rows show
      // each answer as it arrives.
      tidesById: {for (final n in nearby) n.station.id: _loadTides(n.station.id)},
    );
  }

  // A station that fails (some never have predictions) just says its times
  // are unavailable instead of breaking the list.
  _Tides _loadTides(String stationId) => _noaa.tryGetUpcomingHighLows(stationId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stations near ${widget.place.name}'),
        actions: const [HomeButton()],
      ),
      body: FutureBuilder<_NearbyResult>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load stations.'));
          }

          final result = snapshot.data!;
          final nearby = result.nearby;

          if (nearby.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No tide stations within '
                  '${SettingsScope.of(context).formatDistance(_maxMiles, decimals: 0)} of '
                  '${widget.place.description}.\n\n'
                  'NOAA stations cover the US and its territories.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final best = nearby.first.station;

          return ListenableBuilder(
            listenable: favoritesService,
            builder: (context, _) => ListView.builder(
              itemCount: nearby.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _Intro(place: widget.place);

                final item = nearby[index - 1];
                final isBest = index == 1;
                return _NearbyStationTile(
                  item: item,
                  isBestMatch: isBest,
                  bestStation: best,
                  stationsById: result.stationsById,
                  tides: result.tidesById[item.station.id]!,
                  // The best match is the yardstick the others compare to.
                  bestTides: result.tidesById[best.id]!,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final Place place;

  const _Intro({required this.place});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tide stations near ${place.description}. '
            'Star the one you want to see on your home screen.',
          ),
          const SizedBox(height: 8),
          Text(
            'Stations a few miles apart can have very different tides, '
            'especially on the coast versus inland waterways. Compare the '
            'next high tide below with what you expect where you will be. '
            'The ocean, harbor, or waterway tag is a guess from the '
            "station's name. A reference station predicts tides from its own "
            'measurements; an estimated one copies a reference station with '
            'a time and height adjustment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NearbyStationTile extends StatelessWidget {
  final NearbyStation item;
  final bool isBestMatch;
  final Station bestStation;
  final Map<String, Station> stationsById;
  final _Tides tides;
  final _Tides bestTides;

  const _NearbyStationTile({
    required this.item,
    required this.isBestMatch,
    required this.bestStation,
    required this.stationsById,
    required this.tides,
    required this.bestTides,
  });

  // Describes where the station's tides come from.
  String? _sourceLabel(Station station) {
    if (station.isReference) return 'Reference station';
    if (station.isSubordinate) {
      final reference = stationsById[station.referenceId];
      return reference == null
          ? 'Estimated from a nearby reference station'
          : 'Estimated from ${reference.name}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final station = item.station;
    final settings = SettingsScope.of(context);
    final isFavorite = favoritesService.isFavorite(station.id);
    final setting = guessSetting(station.name);
    final source = _sourceLabel(station);

    final details = [setting?.label, source].whereType<String>().join(' • ');

    return ListTile(
      isThreeLine: true,
      title: Text(station.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${settings.formatDistance(item.miles)} away'
            '${isBestMatch ? ' • Best match' : ''}',
          ),
          if (details.isNotEmpty) Text(details),
          _TideSummary(
            tides: tides,
            bestTides: bestTides,
            compareWith: isBestMatch ? null : bestStation,
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(isFavorite ? Icons.star : Icons.star_border),
        color: isFavorite ? Colors.amber : null,
        tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
        onPressed: () => favoritesService.toggle(station.id),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StationDetailScreen(station: station),
        ),
      ),
    );
  }
}

/// The next high tide, and (unless this is the best match) how it compares
/// with the best match's.
class _TideSummary extends StatefulWidget {
  final _Tides tides;
  final _Tides bestTides;

  /// The station to compare against, or null to skip the comparison.
  final Station? compareWith;

  const _TideSummary({
    required this.tides,
    required this.bestTides,
    required this.compareWith,
  });

  @override
  State<_TideSummary> createState() => _TideSummaryState();
}

class _TideSummaryState extends State<_TideSummary> {
  // Created once. Making it inside build() would restart it every time the
  // row rebuilds (for example when the star is tapped).
  late final Future<List<List<Prediction>?>> _both =
      Future.wait([widget.tides, widget.bestTides]);

  @override
  Widget build(BuildContext context) {
    final compareWith = widget.compareWith;
    final settings = SettingsScope.of(context);

    return FutureBuilder<List<List<Prediction>?>>(
      future: _both,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Text('Loading tide times…');
        }

        final own = snapshot.data?[0];
        final best = snapshot.data?[1];
        final nextHigh = own?.where((p) => p.isHigh).firstOrNull;
        if (nextHigh == null) return const Text('Tide times unavailable');

        final comparison = (compareWith == null || best == null)
            ? null
            : compareHighTides(best, own!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next high ${formatTideTime(nextHigh.time, settings)} '
              '• ${settings.formatHeight(nextHigh.value)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (comparison != null)
              Text(describeComparison(comparison, compareWith!.name)),
          ],
        );
      },
    );
  }
}
