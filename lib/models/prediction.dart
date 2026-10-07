/// A single tide prediction from NOAA's `predictions` product.
///
/// With `interval=hilo` each entry is a high or low tide and [type] is set.
/// Without it, entries are 6-minute points on the curve and [type] is null.
class Prediction {
  final DateTime time;
  final double value;

  /// 'H' for high tide, 'L' for low tide. Null for regular interval data.
  final String? type;

  Prediction({required this.time, required this.value, this.type});

  bool get isHigh => type == 'H';
  bool get isLow => type == 'L';

  /// NOAA times have no zone marker. Pass [isUtc] when the request used
  /// `time_zone=gmt`, so the result is a UTC [DateTime] that can be compared
  /// with the clock and converted with `.toLocal()`.
  factory Prediction.fromJson(Map<String, dynamic> json, {bool isUtc = false}) {
    final t = (json['t'] as String).replaceFirst(' ', 'T');
    return Prediction(
      time: DateTime.parse(isUtc ? '${t}Z' : t),
      value: double.parse(json['v'] as String),
      type: json['type'] as String?,
    );
  }
}
