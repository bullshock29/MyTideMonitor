import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/station_locator.dart';

Station _station(String id, double lat, double lng) =>
    Station(id: id, name: 'Station $id', latitude: lat, longitude: lng);

void main() {
  group('distanceInMiles', () {
    test('is zero for the same point', () {
      expect(distanceInMiles(40.7, -74.0, 40.7, -74.0), closeTo(0, 0.001));
    });

    test('matches a known distance (New York to Los Angeles, ~2,445 mi)', () {
      final miles = distanceInMiles(40.7128, -74.0060, 34.0522, -118.2437);
      expect(miles, closeTo(2445, 15));
    });
  });

  group('nearestStations', () {
    // Cape May, NJ
    const lat = 38.935;
    const lng = -74.906;

    final stations = [
      _station('far', 40.7006, -74.0142), // The Battery, ~120 mi away
      _station('near', 38.968, -74.960), // ~4 mi away
      _station('nearer', 38.930, -74.960), // ~3 mi away
      _station('mid', 39.357, -74.418), // Atlantic City, ~40 mi away
    ];

    test('returns stations nearest first', () {
      final result = nearestStations(stations,
          latitude: lat, longitude: lng, maxMiles: 100);
      expect(result.map((n) => n.station.id), ['nearer', 'near', 'mid']);
    });

    test('leaves out stations beyond maxMiles', () {
      final result =
          nearestStations(stations, latitude: lat, longitude: lng, maxMiles: 5);
      expect(result.map((n) => n.station.id), ['nearer', 'near']);
    });

    test('respects count', () {
      final result = nearestStations(stations,
          latitude: lat, longitude: lng, count: 1, maxMiles: 100);
      expect(result.length, 1);
      expect(result.first.station.id, 'nearer');
    });

    test('returns an empty list when nothing is close enough', () {
      final result = nearestStations(stations,
          latitude: 0, longitude: 0); // middle of the Atlantic
      expect(result, isEmpty);
    });
  });

  group('reference stations are preferred', () {
    // Downtown Myrtle Beach, SC. The real stations nearby were:
    // Combination Bridge (subordinate) 2.6 mi, Springmaid Pier (reference) 3.0 mi.
    const lat = 33.689;
    const lng = -78.887;

    final bridge = Station(
      id: 'bridge',
      name: 'Combination Bridge',
      latitude: 33.7133,
      longitude: -78.9217,
      type: 'S',
      referenceId: 'charleston',
    );
    final pier = Station(
      id: 'pier',
      name: 'Springmaid Pier',
      latitude: 33.6550,
      longitude: -78.9183,
      type: 'R',
    );

    test('a slightly farther reference station beats a closer subordinate one',
        () {
      final result =
          nearestStations([bridge, pier], latitude: lat, longitude: lng);
      expect(result.map((n) => n.station.id), ['pier', 'bridge']);
    });

    test('reported distances are the real distances, not the ranking score',
        () {
      final result =
          nearestStations([bridge, pier], latitude: lat, longitude: lng);
      final bridgeMiles = result.last.miles;
      expect(
        bridgeMiles,
        closeTo(distanceInMiles(lat, lng, bridge.latitude, bridge.longitude), 0.001),
      );
    });

    test('a subordinate station still wins when it is much closer', () {
      final veryClose = Station(
        id: 'close',
        name: 'Very close',
        latitude: lat,
        longitude: lng,
        type: 'S',
      );
      final far = Station(
        id: 'far',
        name: 'Far reference',
        latitude: lat + 0.3, // about 20 miles north
        longitude: lng,
        type: 'R',
      );
      final result =
          nearestStations([far, veryClose], latitude: lat, longitude: lng);
      expect(result.first.station.id, 'close');
    });

    test('the penalty can be turned off', () {
      final result = nearestStations([bridge, pier],
          latitude: lat, longitude: lng, subordinatePenaltyMiles: 0);
      expect(result.first.station.id, 'bridge');
    });
  });
}
