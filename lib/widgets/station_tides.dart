import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/services/noaa_service.dart';

/// Loads and shows the upcoming tides for one station: the next high and low
/// as cards, followed by a list of upcoming highs and lows.
///
/// Used by both the station detail screen and the favorites on the home
/// screen. Handles its own loading, error, and retry states.
class StationTides extends StatefulWidget {
  final String stationId;

  /// Limits how many rows the "Upcoming" list shows. Null shows them all.
  final int? upcomingLimit;

  /// Shown directly under the "Next high" and "Next low" tiles, above the
  /// "Upcoming" list. It also stays visible if the tide times fail to load.
  final Widget? belowNextTides;

  /// Whether to show the "Upcoming" list of highs and lows. The home screen
  /// turns it off because it shows a tide chart instead.
  final bool showUpcoming;

  /// Whether to show the note about time zones and what the heights mean.
  /// The home screen leaves it out to save space.
  final bool showNotes;

  const StationTides({
    super.key,
    required this.stationId,
    this.upcomingLimit,
    this.belowNextTides,
    this.showUpcoming = true,
    this.showNotes = true,
  });

  @override
  State<StationTides> createState() => _StationTidesState();
}

class _StationTidesState extends State<StationTides> {
  final _noaa = NoaaService();
  late Future<List<Prediction>> _tides;

  @override
  void initState() {
    super.initState();
    _tides = _noaa.getUpcomingHighLows(widget.stationId);
  }

  void _reload() {
    setState(() => _tides = _noaa.getUpcomingHighLows(widget.stationId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Prediction>>(
      future: _tides,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error is NoaaException
              ? snapshot.error.toString()
              : 'Could not load tide times.';
          return Column(
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(onPressed: _reload, child: const Text('Try again')),
              ?widget.belowNextTides,
            ],
          );
        }

        return _TideTimes(
          tides: snapshot.data!,
          upcomingLimit: widget.upcomingLimit,
          belowNextTides: widget.belowNextTides,
          showUpcoming: widget.showUpcoming,
          showNotes: widget.showNotes,
        );
      },
    );
  }
}

class _TideTimes extends StatelessWidget {
  final List<Prediction> tides;
  final int? upcomingLimit;
  final Widget? belowNextTides;
  final bool showUpcoming;
  final bool showNotes;

  const _TideTimes({
    required this.tides,
    this.upcomingLimit,
    this.belowNextTides,
    this.showUpcoming = true,
    this.showNotes = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tides.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No upcoming tide predictions.'),
          ?belowNextTides,
        ],
      );
    }

    final nextHigh = tides.where((t) => t.isHigh).firstOrNull;
    final nextLow = tides.where((t) => t.isLow).firstOrNull;
    final upcoming = upcomingLimit == null ? tides : tides.take(upcomingLimit!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _NextTideCard(label: 'Next high', tide: nextHigh)),
            const SizedBox(width: 12),
            Expanded(child: _NextTideCard(label: 'Next low', tide: nextLow)),
          ],
        ),
        ?belowNextTides,
        if (showUpcoming || showNotes) const SizedBox(height: 24),
        if (showUpcoming) ...[
          Text('Upcoming', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final tide in upcoming)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                tide.isHigh ? Icons.arrow_upward : Icons.arrow_downward,
              ),
              title: Text(tide.isHigh ? 'High tide' : 'Low tide'),
              subtitle: Text(_formatTime(tide.time)),
              trailing: Text(
                '${tide.value.toStringAsFixed(1)} ft',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (showNotes)
          Text(
            "Times are in your device's time zone. "
            'Heights are feet above mean lower low water (MLLW).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _NextTideCard extends StatelessWidget {
  final String label;
  final Prediction? tide;

  const _NextTideCard({required this.label, required this.tide});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final local = tide?.time.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              local == null ? '—' : DateFormat('h:mm a').format(local),
              style: textTheme.headlineSmall,
            ),
            if (local != null) ...[
              Text(DateFormat('EEE').format(local)),
              Text('${tide!.value.toStringAsFixed(1)} ft'),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime utc) {
  return DateFormat('EEE, MMM d • h:mm a').format(utc.toLocal());
}
