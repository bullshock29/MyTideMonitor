import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/tide_point.dart';
import 'package:my_tide_monitor/services/tide_curve.dart';

DateTime _t(String utc) => DateTime.parse('${utc.replaceFirst(' ', 'T')}Z');

Prediction _high(String utc, double ft) =>
    Prediction(time: _t(utc), value: ft, type: 'H');
Prediction _low(String utc, double ft) =>
    Prediction(time: _t(utc), value: ft, type: 'L');

void main() {
  // Real Springmaid Pier predictions: low 0.629 at 14:38, high 6.003 at 20:48
  // (a 6 h 10 min rise), then low 0.671 at 03:29 the next day.
  final extremes = [
    _low('2026-10-06 14:38', 0.629),
    _high('2026-10-06 20:48', 6.003),
    _low('2026-10-07 03:29', 0.671),
  ];

  group('curveFromExtremes', () {
    final curve = curveFromExtremes(extremes);

    test('starts and ends exactly on the first and last extreme', () {
      expect(curve.first.time, _t('2026-10-06 14:38'));
      expect(curve.first.feet, closeTo(0.629, 1e-9));
      expect(curve.last.time, _t('2026-10-07 03:29'));
      expect(curve.last.feet, closeTo(0.671, 1e-9));
    });

    test('passes through the high at its predicted time', () {
      expect(heightAt(curve, _t('2026-10-06 20:48')), closeTo(6.003, 0.01));
    });

    test('halfway between a low and a high is the average of the two', () {
      // 14:38 to 20:48 is 370 minutes, so the midpoint is 17:43.
      expect(heightAt(curve, _t('2026-10-06 17:43')), closeTo((0.629 + 6.003) / 2, 0.01));
    });

    test('moves slowly near the extremes and fast in the middle', () {
      final nearLow = heightAt(curve, _t('2026-10-06 15:38'))! - 0.629; // 1 h after the low
      final nearMid =
          heightAt(curve, _t('2026-10-06 18:13'))! - heightAt(curve, _t('2026-10-06 17:13'))!;
      expect(nearLow, lessThan(nearMid));
    });

    test('never goes above the high or below the low', () {
      for (final p in curve) {
        expect(p.feet, greaterThanOrEqualTo(0.629 - 1e-9));
        expect(p.feet, lessThanOrEqualTo(6.003 + 1e-9));
      }
    });

    test('has a point every 6 minutes', () {
      expect(curve[1].time.difference(curve[0].time), const Duration(minutes: 6));
    });

    test('needs at least two extremes', () {
      expect(curveFromExtremes([]), isEmpty);
      expect(curveFromExtremes([_high('2026-10-06 20:48', 6.0)]), isEmpty);
    });
  });

  group('heightAt', () {
    final curve = [
      TidePoint(_t('2026-10-06 12:00'), 1.0),
      TidePoint(_t('2026-10-06 12:10'), 2.0),
      TidePoint(_t('2026-10-06 12:20'), 1.0),
    ];

    test('slides between neighbouring points', () {
      expect(heightAt(curve, _t('2026-10-06 12:05')), closeTo(1.5, 1e-9));
      expect(heightAt(curve, _t('2026-10-06 12:15')), closeTo(1.5, 1e-9));
    });

    test('is exact on a point', () {
      expect(heightAt(curve, _t('2026-10-06 12:10')), closeTo(2.0, 1e-9));
    });

    test('is null outside the curve', () {
      expect(heightAt(curve, _t('2026-10-06 11:59')), isNull);
      expect(heightAt(curve, _t('2026-10-06 12:21')), isNull);
    });
  });

  group('isRising', () {
    final curve = curveFromExtremes(extremes);

    test('true on the way up, false on the way down', () {
      expect(isRising(curve, _t('2026-10-06 18:00')), isTrue);
      expect(isRising(curve, _t('2026-10-07 00:00')), isFalse);
    });

    test('is null outside the curve', () {
      expect(isRising(curve, _t('2026-10-08 00:00')), isNull);
    });
  });
}
