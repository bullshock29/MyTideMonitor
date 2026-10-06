/// A plain word for how big waves are, for people heading to the beach.
String waveSizeLabel(double feet) {
  if (feet < 1) return 'Calm';
  if (feet < 2) return 'Small';
  if (feet < 4) return 'Moderate';
  if (feet < 6) return 'Large';
  return 'Very large';
}

/// A wave height rounded to the nearest half foot: "3 ft", "2.5 ft".
String formatWaveFeet(double feet) {
  final rounded = (feet * 2).round() / 2;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return '$text ft';
}

/// "1 to 3 ft", or "2 ft" when the range is a single value.
String formatWaveRange(double minFeet, double maxFeet) {
  final low = formatWaveFeet(minFeet);
  final high = formatWaveFeet(maxFeet);
  if (low == high) return high;
  return '${low.replaceAll(' ft', '')} to $high';
}
