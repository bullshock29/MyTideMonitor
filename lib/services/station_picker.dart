import 'dart:math' as math;

import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/tide_comparison.dart';

/// A station that could represent a place, with its real distance and its
/// upcoming tides.
class Candidate {
  final Station station;
  final double miles;

  /// Upcoming highs and lows, soonest first.
  final List<Prediction> tides;

  Candidate(this.station, this.miles, this.tides);

  Prediction? get nextHigh => tides.where((p) => p.isHigh).firstOrNull;
}

/// Stations count as "close" to a place within this many miles, or twice the
/// distance to the nearest station if that is larger.
const double _minCloseMiles = 5;

/// Two stations "agree" when their high tides are within this long of each
/// other and their heights are within [_agreeHeightRatio]. Real examples:
/// stations in Annapolis and Miami Beach differ by 48 to 57 minutes with
/// similar heights, which isn't worth asking the user about, while Myrtle
/// Beach's ocean and waterway stations differ by 3 to 4 hours and 60%.
const Duration _agreeTime = Duration(minutes: 75);
const (double, double) _agreeHeightRatio = (0.7, 1.43);

bool _agree(Candidate a, Candidate b) {
  final comparison = compareHighTides(a.tides, b.tides);
  // If the tides can't be lined up, don't treat it as a disagreement.
  if (comparison == null) return true;

  return comparison.delay.abs() < _agreeTime &&
      comparison.heightRatio >= _agreeHeightRatio.$1 &&
      comparison.heightRatio <= _agreeHeightRatio.$2;
}

/// Decides which station(s) to offer for a place.
///
/// [ranked] is every usable candidate, best first (stations with no tide
/// data should already be left out). The result is:
/// - one station when the nearby stations agree about the tide, or when only
///   one is close, so the app can just show it; or
/// - up to [maxChoices] stations when nearby stations really disagree, for
///   example the ocean and the waterways behind it, so the user can choose.
///   Stations that agree with a station already offered are skipped, so three
///   waterway stations show up as one choice.
///
/// The first item is always the best match. An empty list means no stations.
List<Candidate> pickStations(List<Candidate> ranked, {int maxChoices = 3}) {
  if (ranked.isEmpty) return [];

  final nearest = ranked.map((c) => c.miles).reduce(math.min);
  final closeMiles = math.max(_minCloseMiles, 2 * nearest);
  final close = ranked.where((c) => c.miles <= closeMiles).toList();
  if (close.isEmpty) return [ranked.first];

  final choices = [close.first];
  for (final candidate in close.skip(1)) {
    if (choices.length >= maxChoices) break;
    if (choices.any((chosen) => _agree(chosen, candidate))) continue;
    choices.add(candidate);
  }
  return choices;
}
