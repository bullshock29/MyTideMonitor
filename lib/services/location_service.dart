import 'package:geolocator/geolocator.dart';

/// Why the phone's location couldn't be read.
enum LocationProblem {
  /// Location is switched off on the phone.
  servicesOff,

  /// The user said no to the permission prompt (it can be asked again).
  denied,

  /// The user said no and chose not to be asked again. Only the phone's
  /// settings can change it now.
  deniedForever,

  /// Permission is fine but no position arrived in time.
  unavailable,
}

class LocationException implements Exception {
  final LocationProblem problem;

  LocationException(this.problem);

  /// A message that can be shown to the user.
  String get message => switch (problem) {
        LocationProblem.servicesOff =>
          'Location is turned off. Turn it on to find tides near you.',
        LocationProblem.denied =>
          'Location permission is needed to find tides near you.',
        LocationProblem.deniedForever =>
          'Location permission is blocked. You can allow it in Settings.',
        LocationProblem.unavailable =>
          'Could not get your location. Try again in a moment.',
      };

  @override
  String toString() => message;
}

typedef Coordinates = ({double latitude, double longitude});

/// Reads the phone's current location (asking for permission if needed).
class LocationService {
  /// The phone's current coordinates. Throws a [LocationException] with the
  /// reason if they can't be read.
  ///
  /// An approximate location is plenty to find the nearest tide station, so
  /// this asks for low accuracy, which also uses less battery.
  Future<Coordinates> getCurrentCoordinates() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException(LocationProblem.servicesOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(LocationProblem.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw LocationException(LocationProblem.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      throw LocationException(LocationProblem.unavailable);
    }
  }

  /// Opens the phone settings screen that can fix [problem], if there is one.
  Future<void> openSettingsFor(LocationProblem problem) async {
    switch (problem) {
      case LocationProblem.servicesOff:
        await Geolocator.openLocationSettings();
      case LocationProblem.deniedForever:
        await Geolocator.openAppSettings();
      case LocationProblem.denied || LocationProblem.unavailable:
        break;
    }
  }
}
