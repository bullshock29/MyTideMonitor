/// A NOAA tide station from the metadata API's `stations` list.
class Station {
  final String id;
  final String name;
  final String? state;
  final double latitude;
  final double longitude;

  /// 'R' for a reference station, 'S' for a subordinate station.
  final String? type;

  /// For a subordinate station, the ID of the reference station its
  /// predictions are derived from. Null otherwise.
  final String? referenceId;

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.state,
    this.type,
    this.referenceId,
  });

  /// Reference stations are predicted from their own long measurement record.
  bool get isReference => type == 'R';

  /// Subordinate stations are estimated from a reference station.
  bool get isSubordinate => type == 'S';

  /// Reads a station from NOAA's JSON. Only the fields we use are kept.
  factory Station.fromJson(Map<String, dynamic> json) {
    final referenceId = json['reference_id'] as String?;
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String?,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      type: json['type'] as String?,
      // NOAA sends an empty string for stations with no reference.
      referenceId: (referenceId == null || referenceId.isEmpty)
          ? null
          : referenceId,
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
      'reference_id': referenceId,
    };
  }
}
