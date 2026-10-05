/// A measured water level reading from NOAA's `water_level` product.
class WaterLevel {
  final DateTime time;
  final double value;

  /// Standard deviation of the 1 second samples used for this reading.
  final double? sigma;

  /// Data quality flags, e.g. "1,0,0,0".
  final String? flags;

  /// Quality level: 'p' preliminary, 'v' verified.
  final String? quality;

  WaterLevel({
    required this.time,
    required this.value,
    this.sigma,
    this.flags,
    this.quality,
  });

  factory WaterLevel.fromJson(Map<String, dynamic> json) {
    final sigma = json['s'] as String?;
    return WaterLevel(
      time: DateTime.parse(json['t'] as String),
      value: double.parse(json['v'] as String),
      // NOAA sends an empty string when a value is unavailable.
      sigma: (sigma == null || sigma.isEmpty) ? null : double.parse(sigma),
      flags: json['f'] as String?,
      quality: json['q'] as String?,
    );
  }
}
