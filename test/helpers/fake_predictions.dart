import 'dart:convert';
import 'dart:math' as math;

/// NOAA writes times as "2026-10-06 04:24" in the zone asked for (UTC here).
String _noaaTime(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}';
}

/// A NOAA "predictions" response of high and low tides every ~6 hours,
/// starting [hoursBefore] hours before [around] and running to [hoursAfter]
/// hours after it. Highs are 5.0 ft and lows 0.5 ft.
String hiloResponse(
  DateTime around, {
  int hoursBefore = 12,
  int hoursAfter = 60,
}) {
  final rows = <Map<String, String>>[];
  var isHigh = true;
  for (var h = -hoursBefore; h <= hoursAfter; h += 6) {
    final time = around.toUtc().add(Duration(hours: h));
    rows.add({
      't': _noaaTime(time),
      'v': isHigh ? '5.000' : '0.500',
      'type': isHigh ? 'H' : 'L',
    });
    isHigh = !isHigh;
  }
  return jsonEncode({'predictions': rows});
}

/// A NOAA "predictions" response of a smooth curve with a point every 6
/// minutes (what reference stations give), covering the same kind of window.
String sixMinuteResponse(
  DateTime around, {
  int hoursBefore = 24,
  int hoursAfter = 48,
}) {
  final rows = <Map<String, String>>[];
  final start = around.toUtc().subtract(Duration(hours: hoursBefore));
  final points = (hoursBefore + hoursAfter) * 10;
  for (var i = 0; i <= points; i++) {
    final time = start.add(Duration(minutes: i * 6));
    // A tide with roughly a 12.4 hour cycle, between 0.5 ft and 5.0 ft.
    final feet = 2.75 + 2.25 * math.sin(i * 6 / 60 / 12.4 * 2 * math.pi);
    rows.add({'t': _noaaTime(time), 'v': feet.toStringAsFixed(3)});
  }
  return jsonEncode({'predictions': rows});
}

/// What NOAA sends when it has no predictions for a station (HTTP 400 or 200).
const String noaaErrorResponse =
    '{"error": {"message":"No Predictions data was found. Please make sure the Datum input is valid."}}';

/// An Open-Meteo marine response: waves of [waveFeet] now, and
/// [waterCelsius] water. Either can be null, as the real service does.
String marineResponse({double? waveFeet = 3.1, double? waterCelsius = 25.3}) {
  return jsonEncode({
    'current': {
      'time': '2026-10-06T13:30',
      'wave_height': waveFeet,
      'sea_surface_temperature': waterCelsius,
    },
    'hourly': {
      'wave_height': waveFeet == null ? [] : [waveFeet, waveFeet + 0.5, waveFeet + 1],
    },
  });
}
