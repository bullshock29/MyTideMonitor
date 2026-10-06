import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/wave_size.dart';

void main() {
  group('WaveConditions.fromJson', () {
    test('reads the current height and the next-day range', () {
      final waves = WaveConditions.fromJson({
        'current': {'time': '2026-10-06T13:30', 'wave_height': 3.084},
        'hourly': {
          'wave_height': [3.1, 3.4, 4.2, 3.9, 2.8],
        },
      })!;
      expect(waves.nowFeet, 3.084);
      expect(waves.next24HoursMinFeet, 2.8);
      expect(waves.next24HoursMaxFeet, 4.2);
    });

    test('the range always includes the current reading', () {
      final waves = WaveConditions.fromJson({
        'current': {'wave_height': 5.0},
        'hourly': {
          'wave_height': [2.0, 3.0],
        },
      })!;
      expect(waves.next24HoursMaxFeet, 5.0);
      expect(waves.next24HoursMinFeet, 2.0);
    });

    test('skips missing hours', () {
      final waves = WaveConditions.fromJson({
        'current': {'wave_height': 2.0},
        'hourly': {
          'wave_height': [null, 1.0, null, 3.0],
        },
      })!;
      expect(waves.next24HoursMinFeet, 1.0);
      expect(waves.next24HoursMaxFeet, 3.0);
    });

    test('no current value (inland places) gives null', () {
      expect(
        WaveConditions.fromJson({
          'current': {'time': '2026-10-06T13:30', 'wave_height': null},
        }),
        isNull,
      );
      expect(WaveConditions.fromJson({}), isNull);
    });

    test('works with no forecast at all', () {
      final waves = WaveConditions.fromJson({
        'current': {'wave_height': 1.5},
      })!;
      expect(waves.next24HoursMinFeet, 1.5);
      expect(waves.next24HoursMaxFeet, 1.5);
    });
  });

  group('waveSizeLabel', () {
    test('boundaries', () {
      expect(waveSizeLabel(0.4), 'Calm');
      expect(waveSizeLabel(1.0), 'Small');
      expect(waveSizeLabel(1.9), 'Small');
      expect(waveSizeLabel(2.0), 'Moderate');
      expect(waveSizeLabel(3.9), 'Moderate');
      expect(waveSizeLabel(4.0), 'Large');
      expect(waveSizeLabel(5.9), 'Large');
      expect(waveSizeLabel(6.0), 'Very large');
    });
  });

  group('formatting', () {
    test('rounds to the nearest half foot', () {
      expect(formatWaveFeet(3.084), '3 ft');
      expect(formatWaveFeet(2.3), '2.5 ft');
      expect(formatWaveFeet(2.7), '2.5 ft');
      expect(formatWaveFeet(0.066), '0 ft');
      expect(formatWaveFeet(11.2), '11 ft');
    });

    test('ranges', () {
      expect(formatWaveRange(1.0, 3.0), '1 to 3 ft');
      expect(formatWaveRange(1.4, 2.6), '1.5 to 2.5 ft');
      expect(formatWaveRange(2.9, 3.1), '3 ft');
    });
  });
}
