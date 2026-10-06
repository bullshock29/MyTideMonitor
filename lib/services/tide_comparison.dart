import 'package:my_tide_monitor/models/prediction.dart';

/// How one station's high tide compares with another's.
class TideComparison {
  /// Positive when the other station's high tide comes later.
  final Duration delay;

  /// The other station's high tide height divided by the base station's.
  final double heightRatio;

  TideComparison({required this.delay, required this.heightRatio});

  /// True when the two stations' tides are, for practical purposes, the same.
  bool get isCloseMatch => _sameTime(delay) && _sameHeight(heightRatio);
}

bool _sameTime(Duration delay) => delay.inMinutes.abs() < 15;
bool _sameHeight(double ratio) => ratio >= 0.9 && ratio <= 1.1;

/// Compares the next high tide at a station ([other]) with the next high tide
/// at a base station ([base]).
///
/// Both lists are upcoming high and low tides, soonest first. The base
/// station's next high tide is matched with the high tide at [other] that is
/// nearest in time, so the comparison is between the same tide cycle. Returns
/// null when there is no sensible match, for example when data is missing.
TideComparison? compareHighTides(List<Prediction> base, List<Prediction> other) {
  final baseHigh = base.where((p) => p.isHigh).firstOrNull;
  if (baseHigh == null || baseHigh.value <= 0) return null;

  Prediction? match;
  for (final p in other.where((p) => p.isHigh)) {
    final gap = p.time.difference(baseHigh.time).abs();
    if (match == null || gap < match.time.difference(baseHigh.time).abs()) {
      match = p;
    }
  }
  // A high tide more than 6 hours away is a different tide cycle.
  if (match == null ||
      match.time.difference(baseHigh.time).abs() > const Duration(hours: 6)) {
    return null;
  }

  return TideComparison(
    delay: match.time.difference(baseHigh.time),
    heightRatio: match.value / baseHigh.value,
  );
}

/// A plain-language sentence, such as:
/// "Compared with Springmaid Pier: high tide arrives about 1 h 50 min later
/// and is about 58% as high."
String describeComparison(TideComparison comparison, String baseName) {
  if (comparison.isCloseMatch) return 'Tides closely match $baseName.';

  final String timePhrase;
  if (_sameTime(comparison.delay)) {
    timePhrase = 'arrives at about the same time';
  } else {
    final minutes = comparison.delay.inMinutes.abs();
    final rounded = (minutes / 5).round() * 5; // 112 min reads as 110 min
    final hours = rounded ~/ 60;
    final rest = rounded % 60;
    final amount = [
      if (hours > 0) '$hours h',
      if (rest > 0 || hours == 0) '$rest min',
    ].join(' ');
    timePhrase =
        'arrives about $amount ${comparison.delay.isNegative ? 'earlier' : 'later'}';
  }

  final String heightPhrase;
  if (_sameHeight(comparison.heightRatio)) {
    heightPhrase = 'is a similar height';
  } else {
    heightPhrase =
        'is about ${(comparison.heightRatio * 100).round()}% as high';
  }

  return 'Compared with $baseName: high tide $timePhrase and $heightPhrase.';
}
