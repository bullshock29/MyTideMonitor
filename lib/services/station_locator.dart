import 'dart:math' as math;

import 'package:my_tide_monitor/models/station.dart';

/// A station together with its distance from some point.
class NearbyStation {
  final Station station;

  /// The real straight-line distance, in miles.
  final double miles;

  NearbyStation(this.station, this.miles);
}

const double _earthRadiusMiles = 3958.8;

/// Great-circle distance in miles between two coordinates (haversine formula).
double distanceInMiles(double lat1, double lng1, double lat2, double lng2) {
  double toRadians(double degrees) => degrees * math.pi / 180;

  final dLat = toRadians(lat2 - lat1);
  final dLng = toRadians(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRadians(lat1)) *
          math.cos(toRadians(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMiles * math.asin(math.sqrt(a));
}

/// The [count] best stations for ([latitude], [longitude]), best first.
///
/// Stations farther than [maxMiles] are left out, so the result can be empty
/// (for example for a place far from any US coast).
///
/// Ranking is by distance, but a subordinate station (whose tides are only
/// estimated from a reference station) is ranked as if it were
/// [subordinatePenaltyMiles] farther away. So a reference station a few miles
/// away beats a slightly closer subordinate one. The distances in the result
/// are always the real ones.
List<NearbyStation> nearestStations(
  List<Station> stations, {
  required double latitude,
  required double longitude,
  int count = 5,
  double maxMiles = 50,
  double subordinatePenaltyMiles = 2,
}) {
  final nearby = <NearbyStation>[];
  for (final station in stations) {
    final miles = distanceInMiles(
      latitude,
      longitude,
      station.latitude,
      station.longitude,
    );
    if (miles <= maxMiles) nearby.add(NearbyStation(station, miles));
  }

  double rank(NearbyStation n) =>
      n.miles + (n.station.isSubordinate ? subordinatePenaltyMiles : 0);

  nearby.sort((a, b) => rank(a).compareTo(rank(b)));
  return nearby.take(count).toList();
}
