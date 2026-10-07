import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/tide_format.dart';
import 'package:my_tide_monitor/services/wave_size.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';

/// How big the waves are near a station: the size now, with a plain word for
/// it, and the range over the next day.
///
/// It shows what is in [marine], which `StationConditions` loads once and
/// shares with the tide chart. It shows nothing when there is nothing
/// trustworthy to say: no marine data was requested (waterway stations), the
/// model has no waves (inland places), or the request failed.
class StationWaves extends StatelessWidget {
  /// The marine data being loaded, or null when none was requested.
  final Future<MarineConditions?>? marine;

  /// Whether to show the small "open-water estimate" explanation. The home
  /// screen leaves it out to save space.
  final bool showNotes;

  const StationWaves({super.key, required this.marine, this.showNotes = true});

  @override
  Widget build(BuildContext context) {
    final marine = this.marine;
    if (marine == null) return const SizedBox.shrink();

    return FutureBuilder<MarineConditions?>(
      future: marine,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Checking waves…'),
          );
        }

        final marineData = snapshot.data;
        final WaveConditions? conditions = marineData?.waves;
        if (marineData == null || conditions == null) {
          return const SizedBox.shrink(); // error or no data
        }

        final textTheme = Theme.of(context).textTheme;
        final colors = Theme.of(context).colorScheme;
        final settings = SettingsScope.of(context);
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
                      'Waves ${formatWaveHeight(conditions.nowFeet, settings)} '
                      '• ${waveSizeLabel(conditions.nowFeet)}',
                      style: textTheme.titleMedium,
                    ),
                    Text(
                      'Next 24 hours: ${formatWaveRange(conditions.next24HoursMinFeet, conditions.next24HoursMaxFeet, settings)}',
                    ),
                    // Waves are a forecast that changes, so a saved copy has
                    // to say how old it is, even on the quick-glance home
                    // screen.
                    if (marineData.fromCache)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off, size: 14, color: colors.error),
                            const SizedBox(width: 4),
                            Text(
                              'Offline • as of ${formatAge(DateTime.now().difference(marineData.fetchedAt))}',
                              style: textTheme.bodySmall?.copyWith(color: colors.error),
                            ),
                          ],
                        ),
                      ),
                    if (showNotes)
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
