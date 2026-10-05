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

  const StationTides({super.key, required this.stationId, this.upcomingLimit});

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
            ],
          );
        }

        return _TideTimes(
          tides: snapshot.data!,
          upcomingLimit: widget.upcomingLimit,
        );
      },
    );
  }
}

class _TideTimes extends StatelessWidget {
  final List<Prediction> tides;
  final int? upcomingLimit;

  const _TideTimes({required this.tides, this.upcomingLimit});

  @override
  Widget build(BuildContext context) {
    if (tides.isEmpty) {
      return const Text('No upcoming tide predictions.');
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
        const SizedBox(height: 24),
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
