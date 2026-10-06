import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/models/tide_point.dart';
import 'package:my_tide_monitor/services/noaa_service.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/tide_curve.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';

/// How much of the curve the chart shows around "now".
const Duration _hoursBefore = Duration(hours: 6);
const Duration _hoursAfter = Duration(hours: 24);

/// Loads a station's tide curve and shows it: the predicted height right now,
/// whether the tide is rising or falling, and a chart from 6 hours ago to
/// 24 hours ahead with a marker at the current time.
class TideChart extends StatefulWidget {
  final Station station;

  /// Marine data being loaded for this station, used for the water
  /// temperature shown beside the tide height. Null when there is none (for
  /// example waterway stations), in which case no temperature is shown. The
  /// chart never waits for it.
  final Future<MarineConditions?>? marine;

  /// Whether to show the explanation under the chart (what the height means
  /// and how it was drawn). The home screen leaves it out to save space.
  final bool showNotes;

  const TideChart({
    super.key,
    required this.station,
    this.marine,
    this.showNotes = true,
  });

  @override
  State<TideChart> createState() => _TideChartState();
}

class _TideChartState extends State<TideChart> {
  final _noaa = NoaaService();
  late Future<TideCurve> _curve;

  @override
  void initState() {
    super.initState();
    _curve = _noaa.getTideCurve(widget.station);
  }

  void _reload() => setState(() => _curve = _noaa.getTideCurve(widget.station));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TideCurve>(
      future: _curve,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                const Text('Could not load the tide chart.'),
                TextButton(onPressed: _reload, child: const Text('Try again')),
              ],
            ),
          );
        }

        // The water temperature fills in when the marine data arrives; until
        // then (or if it never does) the chart simply has no temperature.
        return FutureBuilder<MarineConditions?>(
          future: widget.marine,
          builder: (context, marineSnapshot) => TideChartView(
            curve: snapshot.data!,
            now: DateTime.now(),
            showNotes: widget.showNotes,
            waterTemperatureCelsius: marineSnapshot.data?.waterTemperatureCelsius,
          ),
        );
      },
    );
  }
}

/// Draws a [TideCurve]. Separate from [TideChart] so it can be tested
/// without loading anything.
class TideChartView extends StatelessWidget {
  final TideCurve curve;

  /// The moment the chart is centered on. Passed in so tests can fix it.
  final DateTime now;

  /// Whether to show the explanation under the chart.
  final bool showNotes;

  /// The water temperature in °C, shown on the right of the heading. Null
  /// leaves it out.
  final double? waterTemperatureCelsius;

  const TideChartView({
    super.key,
    required this.curve,
    required this.now,
    this.showNotes = true,
    this.waterTemperatureCelsius,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final settings = SettingsScope.of(context);

    final nowUtc = now.toUtc();
    final currentHeight = heightAt(curve.points, nowUtc);
    if (currentHeight == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text('Tide chart is not available right now.'),
      );
    }
    final rising = isRising(curve.points, nowUtc);

    // Only the part of the curve around now, with x in hours from now and y
    // already converted to the unit being shown, so the axis marks fall on
    // round numbers in that unit.
    final visible = curve.points.where((p) {
      return !p.time.isBefore(nowUtc.subtract(_hoursBefore)) &&
          !p.time.isAfter(nowUtc.add(_hoursAfter));
    }).toList();
    final spots = [
      for (final p in visible)
        FlSpot(
          p.time.difference(nowUtc).inMinutes / 60,
          settings.heightValue(p.feet),
        ),
    ];

    // Half a foot of room above and below the curve, in the shown unit.
    final padding = settings.heightValue(0.5);
    final heights = spots.map((s) => s.y);
    final minY = heights.reduce((a, b) => a < b ? a : b) - padding;
    final maxY = heights.reduce((a, b) => a > b ? a : b) + padding;
    final heightDecimals = settings.heightUnit == HeightUnit.feet ? 1 : 2;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The heading: tide height on the left, water temperature on the
          // right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          settings.formatHeight(currentHeight),
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(width: 8),
                        if (rising != null) ...[
                          Icon(rising ? Icons.arrow_upward : Icons.arrow_downward),
                          Text(
                            rising ? 'Rising' : 'Falling',
                            style: textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                    Text('Tide height now', style: textTheme.bodySmall),
                  ],
                ),
              ),
              if (waterTemperatureCelsius != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      settings.formatTemperature(waterTemperatureCelsius!),
                      style: textTheme.headlineMedium,
                    ),
                    Text('Water temp', style: textTheme.bodySmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: -_hoursBefore.inHours.toDouble(),
                maxX: _hoursAfter.inHours.toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colors.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        // Skip the labels at the very top and bottom edges.
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        // Whole numbers, unless the marks are closer than 1 unit.
                        final decimals = meta.appliedInterval < 1 ? 1 : 0;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            value.toStringAsFixed(decimals),
                            style: textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 6,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final label = value == 0
                            ? 'Now'
                            : settings.formatHour(
                                now.add(Duration(hours: value.round())),
                              );
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(label, style: textTheme.bodySmall),
                        );
                      },
                    ),
                  ),
                ),
                // A dashed line down the chart at the current time.
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: 0,
                      color: colors.primary,
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) => [
                      for (final spot in touched)
                        if (spot.barIndex == 0)
                          LineTooltipItem(
                            '${settings.formatWeekdayClock(now.add(Duration(minutes: (spot.x * 60).round())))}\n'
                            '${spot.y.toStringAsFixed(heightDecimals)} ${settings.heightSymbol}',
                            TextStyle(color: colors.onInverseSurface),
                          )
                        else
                          null,
                    ],
                  ),
                ),
                lineBarsData: [
                  // The tide curve, shaded underneath like water.
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.15,
                    color: colors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  // A dot on the curve at the current time.
                  LineChartBarData(
                    spots: [FlSpot(0, settings.heightValue(currentHeight))],
                    barWidth: 0,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 6,
                        color: colors.primary,
                        strokeWidth: 3,
                        strokeColor: colors.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showNotes) ...[
            const SizedBox(height: 4),
            Text(
              curve.isEstimated
                  ? 'Predicted height in ${settings.heightWord} above mean '
                      'lower low water. Drawn between the predicted high and '
                      'low tides, so it is approximate. Wind and weather can '
                      'change the real water level.'
                  : 'Predicted height in ${settings.heightWord} above mean '
                      "lower low water, from NOAA's 6-minute predictions. "
                      'Wind and weather can change the real water level.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
