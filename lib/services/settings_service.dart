import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit { celsius, fahrenheit }

enum DistanceUnit { kilometers, miles }

enum HeightUnit { feet, meters }

enum TimeFormat { twelveHour, twentyFourHour }

const double _metersPerFoot = 0.3048;
const double _kilometersPerMile = 1.609344;

/// The user's choices for units and the time format, saved on the device.
///
/// The app keeps every measurement in one fixed unit internally (feet, miles,
/// degrees Celsius, UTC times) and only converts when something is shown.
/// All of that converting and formatting is here, so a screen just asks, for
/// example, `settings.formatHeight(5.4)` and gets "5.4 ft" or "1.65 m".
///
/// Extends [ChangeNotifier]; see `SettingsScope` for how screens rebuild
/// when a setting changes.
class SettingsService extends ChangeNotifier {
  static const String _temperatureKey = 'setting_temperature_unit';
  static const String _distanceKey = 'setting_distance_unit';
  static const String _heightKey = 'setting_height_unit';
  static const String _timeKey = 'setting_time_format';

  // Defaults suit the US coasts that NOAA covers.
  TemperatureUnit _temperatureUnit = TemperatureUnit.fahrenheit;
  DistanceUnit _distanceUnit = DistanceUnit.miles;
  HeightUnit _heightUnit = HeightUnit.feet;
  TimeFormat _timeFormat = TimeFormat.twelveHour;

  TemperatureUnit get temperatureUnit => _temperatureUnit;
  DistanceUnit get distanceUnit => _distanceUnit;
  HeightUnit get heightUnit => _heightUnit;
  TimeFormat get timeFormat => _timeFormat;

  /// Loads the saved choices. Call once at startup, before `runApp`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _temperatureUnit = _read(
      TemperatureUnit.values,
      prefs.getString(_temperatureKey),
      _temperatureUnit,
    );
    _distanceUnit = _read(
      DistanceUnit.values,
      prefs.getString(_distanceKey),
      _distanceUnit,
    );
    _heightUnit = _read(
      HeightUnit.values,
      prefs.getString(_heightKey),
      _heightUnit,
    );
    _timeFormat = _read(
      TimeFormat.values,
      prefs.getString(_timeKey),
      _timeFormat,
    );
    notifyListeners();
  }

  // Finds the enum value saved under [name], or [fallback] if it's missing
  // or no longer exists.
  T _read<T extends Enum>(List<T> values, String? name, T fallback) {
    return values.firstWhere((v) => v.name == name, orElse: () => fallback);
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    if (unit == _temperatureUnit) return;
    _temperatureUnit = unit;
    notifyListeners();
    await _save(_temperatureKey, unit.name);
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    if (unit == _distanceUnit) return;
    _distanceUnit = unit;
    notifyListeners();
    await _save(_distanceKey, unit.name);
  }

  Future<void> setHeightUnit(HeightUnit unit) async {
    if (unit == _heightUnit) return;
    _heightUnit = unit;
    notifyListeners();
    await _save(_heightKey, unit.name);
  }

  Future<void> setTimeFormat(TimeFormat format) async {
    if (format == _timeFormat) return;
    _timeFormat = format;
    notifyListeners();
    await _save(_timeKey, format.name);
  }

  // The screen updates right away; saving happens in the background.
  Future<void> _save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // ---- Heights (stored in feet) ----

  bool get _useFeet => _heightUnit == HeightUnit.feet;

  /// "ft" or "m".
  String get heightSymbol => _useFeet ? 'ft' : 'm';

  /// "feet" or "meters", for sentences.
  String get heightWord => _useFeet ? 'feet' : 'meters';

  /// [feet] converted to the chosen unit, as a plain number.
  double heightValue(double feet) => _useFeet ? feet : feet * _metersPerFoot;

  /// A height with its unit: "5.4 ft" or "1.65 m".
  ///
  /// [decimals] defaults to 1 for feet and 2 for meters, since a meter is a
  /// much bigger step than a foot.
  String formatHeight(double feet, {int? decimals}) {
    final text = _number(heightValue(feet), decimals ?? (_useFeet ? 1 : 2));
    return '$text $heightSymbol';
  }

  // ---- Distances (stored in miles) ----

  bool get _useMiles => _distanceUnit == DistanceUnit.miles;

  /// "mi" or "km".
  String get distanceSymbol => _useMiles ? 'mi' : 'km';

  /// [miles] converted to the chosen unit, as a plain number.
  double distanceValue(double miles) =>
      _useMiles ? miles : miles * _kilometersPerMile;

  /// A distance with its unit: "3.0 mi" or "4.8 km".
  String formatDistance(double miles, {int decimals = 1}) {
    return '${_number(distanceValue(miles), decimals)} $distanceSymbol';
  }

  // ---- Temperatures (stored in degrees Celsius) ----

  /// A temperature with its unit: "72°F" or "22°C".
  String formatTemperature(double celsius, {int decimals = 0}) {
    if (_temperatureUnit == TemperatureUnit.celsius) {
      return '${_number(celsius, decimals)}°C';
    }
    return '${_number(celsius * 9 / 5 + 32, decimals)}°F';
  }

  // ---- Times ----

  bool get _use24Hour => _timeFormat == TimeFormat.twentyFourHour;

  /// A time of day: "4:48 PM" or "16:48". [local] should already be in the
  /// device's time zone (call `.toLocal()` on UTC times).
  String formatClock(DateTime local) {
    return DateFormat(_use24Hour ? 'HH:mm' : 'h:mm a').format(local);
  }

  /// Just the hour, for chart labels: "4 PM" or "16:00".
  String formatHour(DateTime local) {
    return DateFormat(_use24Hour ? 'HH:00' : 'h a').format(local);
  }

  /// "Wed 4:48 PM" or "Wed 16:48".
  String formatWeekdayClock(DateTime local) {
    return '${DateFormat('EEE').format(local)} ${formatClock(local)}';
  }

  /// "Wed, Oct 7 • 4:48 PM" or "Wed, Oct 7 • 16:48".
  String formatDateClock(DateTime local) {
    return '${DateFormat('EEE, MMM d').format(local)} • ${formatClock(local)}';
  }

  // Rounds to [decimals] places, without ever printing "-0.0".
  String _number(double value, int decimals) {
    final text = value.toStringAsFixed(decimals);
    return double.parse(text) == 0 ? (0.0).toStringAsFixed(decimals) : text;
  }
}

/// The one shared instance used across the app.
final settingsService = SettingsService();
