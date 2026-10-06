/// A place (city, cape, beach...) returned by the geocoding search.
class Place {
  final String name;
  final double latitude;
  final double longitude;

  /// State or province, e.g. "New Jersey". Not always provided.
  final String? region;
  final String? country;

  Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
  });

  /// Reads a place from an Open-Meteo geocoding result.
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      region: json['admin1'] as String?,
      country: json['country'] as String?,
    );
  }

  /// "Cape May, New Jersey, United States" (skipping any missing parts).
  String get description => [name, region, country].whereType<String>().join(', ');

  /// Everything after the name, for use as a subtitle.
  String get locationDetail => [region, country].whereType<String>().join(', ');
}
