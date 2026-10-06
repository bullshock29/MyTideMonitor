/// Open-water wave height now and over the next day, in feet.
class WaveConditions {
  final double nowFeet;
  final double next24HoursMinFeet;
  final double next24HoursMaxFeet;

  WaveConditions({
    required this.nowFeet,
    required this.next24HoursMinFeet,
    required this.next24HoursMaxFeet,
  });

  /// Reads an Open-Meteo marine API response that was requested with
  /// `current=wave_height`, `hourly=wave_height` and `length_unit=imperial`.
  ///
  /// Returns null when there is no wave data, which is what the API sends for
  /// inland places and some sheltered bays.
  static WaveConditions? fromJson(Map<String, dynamic> json) {
    final now = (json['current'] as Map<String, dynamic>?)?['wave_height'] as num?;
    if (now == null) return null;

    final hourly =
        ((json['hourly'] as Map<String, dynamic>?)?['wave_height'] as List?)
                ?.whereType<num>()
                .map((v) => v.toDouble())
                .toList() ??
            [];

    // If there is no forecast, the range is just the current reading.
    final nowFeet = now.toDouble();
    final all = [nowFeet, ...hourly];
    all.sort();

    return WaveConditions(
      nowFeet: nowFeet,
      next24HoursMinFeet: all.first,
      next24HoursMaxFeet: all.last,
    );
  }
}
