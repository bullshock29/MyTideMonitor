import 'dart:math' as math;

import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/tide_point.dart';

/// Draws a tide curve through predicted highs and lows.
///
/// Between one extreme and the next, the water follows a half cosine wave:
/// it moves slowly near a high or low and fastest halfway between. Checked
/// against NOAA's real 6-minute predictions, this is off by about 0.02 to
/// 0.14 ft on average (at worst 0.06 to 0.41 ft) at the stations tried.
///
/// [extremes] must be highs and lows, soonest first. The curve runs from the
/// first extreme to the last, with a point every [step].
List<TidePoint> curveFromExtremes(
  List<Prediction> extremes, {
  Duration step = const Duration(minutes: 6),
}) {
  if (extremes.length < 2) return [];

  final points = <TidePoint>[];
  for (var i = 0; i < extremes.length - 1; i++) {
    final from = extremes[i];
    final to = extremes[i + 1];
    final span = to.time.difference(from.time);
    if (span <= Duration.zero) continue;

    // Don't repeat the shared point where one segment meets the next.
    for (var t = from.time;
        t.isBefore(to.time);
        t = t.add(step)) {
      final fraction = t.difference(from.time).inSeconds / span.inSeconds;
      final eased = (1 - math.cos(math.pi * fraction)) / 2;
      points.add(TidePoint(t, from.value + (to.value - from.value) * eased));
    }
  }
  points.add(TidePoint(extremes.last.time, extremes.last.value));
  return points;
}

/// The height at [time], found by sliding between the two nearest points.
/// Null if [time] is outside the curve.
double? heightAt(List<TidePoint> curve, DateTime time) {
  for (var i = 0; i < curve.length - 1; i++) {
    final a = curve[i];
    final b = curve[i + 1];
    if (time.isBefore(a.time) || time.isAfter(b.time)) continue;

    final span = b.time.difference(a.time).inSeconds;
    if (span == 0) return a.feet;
    final fraction = time.difference(a.time).inSeconds / span;
    return a.feet + (b.feet - a.feet) * fraction;
  }
  return null;
}

/// True if the tide is coming in at [time], false if going out. Null if the
/// curve doesn't cover a few minutes either side of [time].
bool? isRising(List<TidePoint> curve, DateTime time) {
  const gap = Duration(minutes: 5);
  final before = heightAt(curve, time.subtract(gap));
  final after = heightAt(curve, time.add(gap));
  if (before == null || after == null) return null;
  return after > before;
}
