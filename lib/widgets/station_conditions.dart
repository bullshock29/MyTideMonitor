import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/marine_service.dart';
import 'package:my_tide_monitor/services/station_hint.dart';
import 'package:my_tide_monitor/widgets/station_waves.dart';
import 'package:my_tide_monitor/widgets/tide_chart.dart';

/// The waves and the tide chart (with the water temperature) for a station.
///
/// This loads the marine data once and hands it to both parts, since the
/// wave line and the chart's water temperature come from the same request.
/// Used by the home screen cards and the station detail screen.
class StationConditions extends StatefulWidget {
  final Station station;

  /// Whether to show the small explanations under the waves and the chart.
  /// The home screen leaves them out to save space.
  final bool showNotes;

  const StationConditions({
    super.key,
    required this.station,
    this.showNotes = true,
  });

  @override
  State<StationConditions> createState() => _StationConditionsState();
}

class _StationConditionsState extends State<StationConditions> {
  // Null when the station is on a waterway. The model only knows the open
  // water beyond it (it reported 3 ft waves for a creek), so showing waves or
  // water temperature there would mislead.
  Future<MarineConditions?>? _marine;

  @override
  void initState() {
    super.initState();
    final onWaterway = guessSetting(widget.station.name) == StationSetting.waterway;
    if (!onWaterway) {
      _marine = MarineService().getConditions(
        widget.station.latitude,
        widget.station.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StationWaves(marine: _marine, showNotes: widget.showNotes),
        TideChart(
          station: widget.station,
          marine: _marine,
          showNotes: widget.showNotes,
        ),
      ],
    );
  }
}
