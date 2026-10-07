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

  /// When the predictions were loaded (or, for a saved copy, saved).
  final DateTime fetchedAt;

  /// True when there was no connection and this is a copy saved earlier.
  /// Predictions don't go out of date, so it's still right for as long as it
  /// covers the time being asked about.
  final bool fromCache;

  TideCurve(
    this.points, {
    required this.isEstimated,
    DateTime? fetchedAt,
    this.fromCache = false,
  }) : fetchedAt = fetchedAt ?? DateTime.now();
}
