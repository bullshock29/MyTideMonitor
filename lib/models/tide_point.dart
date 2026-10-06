/// The predicted tide height at one moment.
class TidePoint {
  /// UTC. Call `.toLocal()` to show it on the device.
  final DateTime time;

  /// Feet above mean lower low water (MLLW).
  final double feet;

  TidePoint(this.time, this.feet);
}

/// A smooth tide curve over a stretch of time, oldest point first.
class TideCurve {
  final List<TidePoint> points;

  /// True when the curve was drawn between predicted highs and lows because
  /// NOAA only publishes those for the station. False when NOAA's own
  /// 6-minute predictions were used.
  final bool isEstimated;

  TideCurve(this.points, {required this.isEstimated});
}
