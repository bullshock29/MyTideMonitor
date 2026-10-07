import 'package:my_tide_monitor/services/settings_service.dart';

/// A plain word for how big waves are, for people heading to the beach.
///
/// Takes feet, whatever unit is being displayed: the size words are the same
/// for everyone.
String waveSizeLabel(double feet) {
  if (feet < 1) return 'Calm';
  if (feet < 2) return 'Small';
  if (feet < 4) return 'Moderate';
  if (feet < 6) return 'Large';
  return 'Very large';
}

// The wave height as a number in the chosen unit, rounded the way people say
// it: feet to the nearest half foot ("2.5"), meters to the nearest 0.1 ("0.8").
String _waveNumber(double feet, SettingsService settings) {
  if (settings.heightUnit == HeightUnit.feet) {
    final rounded = (feet * 2).round() / 2;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }
  return settings.heightValue(feet).toStringAsFixed(1);
}

/// A wave height with its unit: "3 ft", "2.5 ft", or "0.9 m".
String formatWaveHeight(double feet, SettingsService settings) {
  return '${_waveNumber(feet, settings)} ${settings.heightSymbol}';
}

/// "1 to 3 ft" or "0.3 to 0.9 m", or just "2 ft" when both ends are equal.
String formatWaveRange(
  double minFeet,
  double maxFeet,
  SettingsService settings,
) {
  final low = _waveNumber(minFeet, settings);
  final high = _waveNumber(maxFeet, settings);
  if (low == high) return '$high ${settings.heightSymbol}';
  return '$low to $high ${settings.heightSymbol}';
}
