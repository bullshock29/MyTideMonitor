/// A NOAA tide station from the metadata API's `stations` list.
class Station {
  final String id;
  final String name;
  final String? state;
  final double latitude;
  final double longitude;

  /// 'R' for a reference station, 'S' for a subordinate station.
  final String? type;

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.state,
    this.type,
  });

  /// Reads a station from NOAA's JSON. Only the fields we use are kept.
  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String?,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      type: json['type'] as String?,
    );
  }

  /// Writes the trimmed station for the local cache.
  /// The keys match NOAA's, so [Station.fromJson] reads it back.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'lat': latitude,
      'lng': longitude,
      'type': type,
    };
  }
}
