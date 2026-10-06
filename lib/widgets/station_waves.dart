import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/station_hint.dart';
import 'package:my_tide_monitor/services/wave_service.dart';
import 'package:my_tide_monitor/services/wave_size.dart';

/// How big the waves are near a station: the size now, with a plain word for
/// it, and the range over the next day.
///
/// Shows nothing when there's nothing trustworthy to say: for stations on
/// waterways (the model would report the open ocean beyond them), where the
/// model has no waves (inland places), or when the request fails.
class StationWaves extends StatefulWidget {
  final Station station;

  /// Whether to show the small "open-water estimate" explanation. The home
  /// screen leaves it out to save space.
  final bool showNotes;

  const StationWaves({super.key, required this.station, this.showNotes = true});

  @override
  State<StationWaves> createState() => _StationWavesState();
}

class _StationWavesState extends State<StationWaves> {
  Future<WaveConditions?>? _waves;

  bool get _isWaterway => guessSetting(widget.station.name) == StationSetting.waterway;

  @override
  void initState() {
    super.initState();
    if (!_isWaterway) {
      _waves = WaveService().getWaves(
        widget.station.latitude,
        widget.station.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final waves = _waves;
    if (waves == null) return const SizedBox.shrink();

    return FutureBuilder<WaveConditions?>(
      future: waves,
      builder: (context, snapshot) {
        final conditions = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Checking waves…'),
          );
        }
        if (conditions == null) return const SizedBox.shrink(); // error or no data

        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.waves),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waves ${formatWaveFeet(conditions.nowFeet)} '
                      '• ${waveSizeLabel(conditions.nowFeet)}',
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      'Next 24 hours: ${formatWaveRange(conditions.next24HoursMinFeet, conditions.next24HoursMaxFeet)}',
                    ),
                    if (widget.showNotes)
                      Text(
                        'Open-water estimate. Surf at the beach can be '
                        'smaller or larger.',
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
