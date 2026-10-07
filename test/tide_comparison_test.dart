import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/services/station_hint.dart';
import 'package:my_tide_monitor/services/tide_comparison.dart';

Prediction _high(String utc, double ft) => Prediction(
      time: DateTime.parse('${utc.replaceFirst(' ', 'T')}Z'),
      value: ft,
      type: 'H',
    );

Prediction _low(String utc, double ft) => Prediction(
      time: DateTime.parse('${utc.replaceFirst(' ', 'T')}Z'),
      value: ft,
      type: 'L',
    );

void main() {
  group('compareHighTides', () {
    // Real predictions for 2026-10-06: Springmaid Pier and the airport.
    final springmaid = [
      _high('2026-10-06 20:48', 6.003),
      _low('2026-10-07 03:29', 0.671),
      _high('2026-10-07 09:22', 5.677),
    ];
    final airport = [
      _high('2026-10-06 22:37', 3.514),
      _low('2026-10-07 05:33', 0.588),
      _high('2026-10-07 11:08', 3.297),
    ];

    test('finds the delay and height ratio', () {
      final c = compareHighTides(springmaid, airport)!;
      expect(c.delay, const Duration(minutes: 109));
      expect(c.heightRatio, closeTo(0.585, 0.001));
      expect(c.isCloseMatch, isFalse);
    });

    test('the other station arriving earlier gives a negative delay', () {
      final c = compareHighTides(airport, springmaid)!;
      expect(c.delay, const Duration(minutes: -109));
    });

    test('matches the same tide cycle, not just the next high in the list', () {
      // The other station's first high is 11 hours away, so it's a different
      // cycle, but its second high is 1 hour away.
      final base = [_high('2026-10-06 12:00', 5.0)];
      final other = [
        _high('2026-10-06 01:00', 4.0),
        _high('2026-10-06 13:00', 4.0),
      ];
      expect(compareHighTides(base, other)!.delay, const Duration(hours: 1));
    });

    test('returns null when there is no high tide to compare', () {
      expect(compareHighTides([_low('2026-10-06 12:00', 0.5)], airport), isNull);
      expect(compareHighTides(springmaid, []), isNull);
    });

    test('returns null when the nearest high is a different cycle', () {
      final base = [_high('2026-10-06 12:00', 5.0)];
      final other = [_high('2026-10-06 21:00', 5.0)]; // 9 hours away
      expect(compareHighTides(base, other), isNull);
    });
  });

  group('describeComparison', () {
    test('delayed and shorter', () {
      final c = TideComparison(
        delay: const Duration(minutes: 109),
        heightRatio: 0.585,
      );
      expect(
        describeComparison(c, 'Springmaid Pier'),
        'Compared with Springmaid Pier: high tide arrives about 1 h 50 min '
        'later and is about 59% as high.',
      );
    });

    test('earlier and taller, under an hour', () {
      final c = TideComparison(
        delay: const Duration(minutes: -40),
        heightRatio: 1.3,
      );
      expect(
        describeComparison(c, 'X'),
        'Compared with X: high tide arrives about 40 min earlier and is '
        'about 130% as high.',
      );
    });

    test('same time but different height', () {
      final c = TideComparison(
        delay: const Duration(minutes: 5),
        heightRatio: 0.5,
      );
      expect(
        describeComparison(c, 'X'),
        'Compared with X: high tide arrives at about the same time and is '
        'about 50% as high.',
      );
    });

    test('a close match is said plainly', () {
      final c = TideComparison(
        delay: const Duration(minutes: 3),
        heightRatio: 0.97,
      );
      expect(describeComparison(c, 'X'), 'Tides closely match X.');
    });
  });

  group('guessSetting', () {
    test('real NOAA station names near Myrtle Beach and Cape May', () {
      expect(guessSetting('Springmaid Pier, Myrtle beach'), StationSetting.oceanCoast);
      expect(guessSetting('Garden City Pier (ocean)'), StationSetting.oceanCoast);
      expect(guessSetting('Cape May, Atlantic Ocean'), StationSetting.oceanCoast);
      expect(guessSetting('Myrtle Beach, Combination Bridge'), StationSetting.waterway);
      expect(guessSetting('Carolina Forest, ICWW'), StationSetting.waterway);
      expect(guessSetting('Cape Island Creek, Cape May'), StationSetting.waterway);
      expect(guessSetting('Cape May Harbor'), StationSetting.harborOrBay);
    });

    test('a name with no clue gives null', () {
      expect(guessSetting('HONOLULU'), isNull);
      expect(guessSetting('Cape May, ferry terminal'), isNull);
    });

    test('a strong ocean word beats a waterway word', () {
      expect(guessSetting('Ocean City Inlet Bridge Pier'), StationSetting.oceanCoast);
    });
  });
}
