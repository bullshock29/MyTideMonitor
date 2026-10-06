import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/services/station_picker.dart';

DateTime _t(String utc) => DateTime.parse('${utc.replaceFirst(' ', 'T')}Z');

/// A station whose next high tide is at [high] (UTC) with height [feet].
Candidate _candidate(String id, double miles, String high, double feet,
    {String type = 'S'}) {
  return Candidate(
    Station(id: id, name: id, latitude: 0, longitude: 0, type: type),
    miles,
    [
      Prediction(time: _t(high), value: feet, type: 'H'),
      Prediction(
        time: _t(high).add(const Duration(hours: 6)),
        value: 0.5,
        type: 'L',
      ),
    ],
  );
}

List<String> _ids(List<Candidate> picked) =>
    picked.map((c) => c.station.id).toList();

void main() {
  test('no stations gives an empty list', () {
    expect(pickStations([]), isEmpty);
  });

  test('stations that agree give a single answer (Cape May)', () {
    // Real next highs, within about 25 minutes and 5.1 to 5.4 ft.
    final picked = pickStations([
      _candidate('creek', 0.9, '2026-10-06 21:37', 5.4),
      _candidate('harbor', 1.2, '2026-10-06 21:29', 5.3),
      _candidate('ocean', 1.6, '2026-10-06 21:31', 5.4),
      _candidate('ferry', 3.7, '2026-10-06 22:01', 5.6, type: 'R'),
      _candidate('wildwood', 5.2, '2026-10-06 21:13', 5.1, type: 'R'),
    ]);
    expect(_ids(picked), ['creek']);
  });

  test('ocean versus waterways gives a choice, grouped (Myrtle Beach)', () {
    // The ocean pier is hours earlier and much taller than three waterway
    // stations, which agree with each other and count as one choice.
    final picked = pickStations([
      _candidate('pier', 3.0, '2026-10-06 20:48', 6.0, type: 'R'),
      _candidate('bridge', 2.6, '2026-10-07 00:24', 2.2),
      _candidate('nmb', 4.6, '2026-10-06 23:43', 2.3),
      _candidate('socastee', 4.9, '2026-10-07 00:55', 2.6),
    ]);
    expect(_ids(picked), ['pier', 'bridge']);
  });

  test('a far-away disagreeing station is ignored (Wilmington)', () {
    // The ICWW station is 7.7 mi away, beyond the close range for a place
    // whose nearest station is 0.7 mi away, so no question is asked.
    final picked = pickStations([
      _candidate('wilmington', 0.7, '2026-10-07 00:00', 5.1, type: 'R'),
      _candidate('shinn', 7.7, '2026-10-06 22:02', 4.9, type: 'R'),
    ]);
    expect(_ids(picked), ['wilmington']);
  });

  test('offers at most maxChoices, best first (Ocean City)', () {
    final picked = pickStations([
      _candidate('pier', 0.7, '2026-10-06 20:00', 4.1, type: 'R'),
      _candidate('inlet', 0.7, '2026-10-06 21:45', 2.8, type: 'R'),
      _candidate('keydash', 0.4, '2026-10-06 19:03', 1.9),
      _candidate('bay', 0.4, '2026-10-06 21:22', 2.7),
    ]);
    expect(_ids(picked).first, 'pier');
    expect(picked.length, lessThanOrEqualTo(3));
    expect(_ids(picked), containsAll(['pier', 'inlet', 'keydash']));
  });

  test('a lone station far away is returned on its own', () {
    final picked = pickStations([
      _candidate('far', 30, '2026-10-06 21:00', 3.0, type: 'R'),
    ]);
    expect(_ids(picked), ['far']);
  });

  test('similar time but very different height is a disagreement', () {
    final picked = pickStations([
      _candidate('a', 1.0, '2026-10-06 21:00', 6.0),
      _candidate('b', 1.5, '2026-10-06 21:10', 2.0),
    ]);
    expect(_ids(picked), ['a', 'b']);
  });
}
