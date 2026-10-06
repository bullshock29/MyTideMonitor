import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/place.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/screens/nearby_stations_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/noaa_service.dart';
import 'package:my_tide_monitor/services/station_hint.dart';
import 'package:my_tide_monitor/services/station_locator.dart';
import 'package:my_tide_monitor/services/station_picker.dart';
import 'package:my_tide_monitor/services/station_repository.dart';
import 'package:my_tide_monitor/services/tide_format.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';
import 'package:my_tide_monitor/widgets/station_tides.dart';

/// What the screen found: the station(s) to offer, and whether any stations
/// exist near the place at all.
typedef _Outcome = ({List<Candidate> choices, bool anyStations});

/// Shows the tides for a [Place], picking the station for the user.
///
/// When the nearby stations agree, it shows one answer. When they really
/// disagree (the ocean versus the waterways behind it), it asks the user to
/// choose. Either way the user can add the result to their home screen, or
/// look at all the nearby stations.
class PlaceTidesScreen extends StatefulWidget {
  final Place place;

  const PlaceTidesScreen({super.key, required this.place});

  @override
  State<PlaceTidesScreen> createState() => _PlaceTidesScreenState();
}

class _PlaceTidesScreenState extends State<PlaceTidesScreen> {
  static const double _maxMiles = 50;

  final _noaa = NoaaService();
  late Future<_Outcome> _outcome;

  @override
  void initState() {
    super.initState();
    _outcome = _load();
  }

  Future<_Outcome> _load() async {
    final stations = await StationRepository().getStations();
    final ranked = nearestStations(
      stations,
      latitude: widget.place.latitude,
      longitude: widget.place.longitude,
      count: 6,
      maxMiles: _maxMiles,
    );

    final tides = await Future.wait(
      ranked.map((n) => _noaa.tryGetUpcomingHighLows(n.station.id)),
    );

    // Leave out stations with no usable tide data.
    final candidates = [
      for (var i = 0; i < ranked.length; i++)
        if (tides[i] != null && tides[i]!.any((p) => p.isHigh))
          Candidate(ranked[i].station, ranked[i].miles, tides[i]!),
    ];

    return (choices: pickStations(candidates), anyStations: ranked.isNotEmpty);
  }

  void _retry() => setState(() => _outcome = _load());

  void _seeAllStations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NearbyStationsScreen(place: widget.place)),
    );
  }

  // Adds the station to the home screen, then goes back there.
  Future<void> _addAndGoHome(Station station) async {
    if (!favoritesService.isFavorite(station.id)) {
      await favoritesService.toggle(station.id);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${station.name} to your home screen')),
    );
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.place.name)),
      body: FutureBuilder<_Outcome>(
        future: _outcome,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Centered(
              spinner: true,
              text: 'Finding the best tide station…',
            );
          }

          if (snapshot.hasError) {
            return _Centered(
              text: 'Could not load tide stations.',
              action: FilledButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            );
          }

          final outcome = snapshot.data!;

          if (!outcome.anyStations) {
            return _Centered(
              text: 'No tide stations within '
                  '${SettingsScope.of(context).formatDistance(_maxMiles, decimals: 0)} of '
                  '${widget.place.description}.\n\n'
                  'NOAA stations cover the US and its territories.',
            );
          }

          if (outcome.choices.isEmpty) {
            return _Centered(
              text: 'Tide times are not available for the stations near '
                  '${widget.place.name} right now.',
              action: FilledButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            );
          }

          return ListenableBuilder(
            listenable: favoritesService,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (outcome.choices.length == 1)
                  ..._singleResult(outcome.choices.first)
                else
                  ..._choiceResult(outcome.choices),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _seeAllStations,
                  child: const Text('Not the right spot? See other nearby stations'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _singleResult(Candidate candidate) {
    final station = candidate.station;
    final isFavorite = favoritesService.isFavorite(station.id);

    return [
      Text(
        'Tides for ${widget.place.description}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(station.name, style: Theme.of(context).textTheme.titleMedium),
              Text('${SettingsScope.of(context).formatDistance(candidate.miles)} away'),
              const SizedBox(height: 16),
              StationTides(stationId: station.id, upcomingLimit: 3),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (isFavorite)
        OutlinedButton.icon(
          onPressed: null, // nothing to do; it is already added
          icon: const Icon(Icons.check),
          label: const Text('On your home screen'),
        )
      else
        FilledButton.icon(
          onPressed: () => _addAndGoHome(station),
          icon: const Icon(Icons.add),
          label: const Text('Add to my home screen'),
        ),
    ];
  }

  List<Widget> _choiceResult(List<Candidate> choices) {
    return [
      Text(
        'Tides differ near ${widget.place.name}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Stations a few miles apart have different tides here, usually the '
        'open coast versus the waterways behind it. Higher, earlier tides are '
        'normally on the coast. Pick the one that matches where you will be.',
      ),
      const SizedBox(height: 16),
      for (final candidate in choices)
        _ChoiceCard(
          candidate: candidate,
          isOnHomeScreen: favoritesService.isFavorite(candidate.station.id),
          onTap: () => _addAndGoHome(candidate.station),
        ),
    ];
  }
}

class _ChoiceCard extends StatelessWidget {
  final Candidate candidate;
  final bool isOnHomeScreen;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.candidate,
    required this.isOnHomeScreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final station = candidate.station;
    final setting = guessSetting(station.name);
    final high = candidate.nextHigh;
    final textTheme = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name, style: textTheme.titleMedium),
                    if (setting != null) Text(setting.label),
                    const SizedBox(height: 8),
                    if (high != null)
                      Text(
                        'Next high ${formatTideTime(high.time, settings)} '
                        '• ${settings.formatHeight(high.value)}',
                        style: textTheme.titleSmall,
                      ),
                    Text('${settings.formatDistance(candidate.miles)} away'),
                  ],
                ),
              ),
              Icon(isOnHomeScreen ? Icons.check_circle : Icons.add_circle_outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final bool spinner;
  final String text;
  final Widget? action;

  const _Centered({this.spinner = false, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
