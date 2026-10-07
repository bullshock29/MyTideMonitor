import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/wave_size.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('formatting in feet', () {
    final feet = SettingsService(); // feet is the default

    test('rounds to the nearest half foot', () {
      expect(formatWaveHeight(3.084, feet), '3 ft');
      expect(formatWaveHeight(2.3, feet), '2.5 ft');
      expect(formatWaveHeight(2.7, feet), '2.5 ft');
      expect(formatWaveHeight(0.066, feet), '0 ft');
      expect(formatWaveHeight(11.2, feet), '11 ft');
    });

    test('ranges', () {
      expect(formatWaveRange(1.0, 3.0, feet), '1 to 3 ft');
      expect(formatWaveRange(1.4, 2.6, feet), '1.5 to 2.5 ft');
      expect(formatWaveRange(2.9, 3.1, feet), '3 ft');
    });
  });

  group('formatting in meters', () {
    late SettingsService meters;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      meters = SettingsService();
      await meters.setHeightUnit(HeightUnit.meters);
    });

    test('rounds to the nearest 0.1 m', () {
      expect(formatWaveHeight(3.084, meters), '0.9 m'); // 0.94 m
      expect(formatWaveHeight(6.56, meters), '2.0 m');
      expect(formatWaveHeight(0.066, meters), '0.0 m');
    });

    test('ranges', () {
      expect(formatWaveRange(1.0, 3.0, meters), '0.3 to 0.9 m');
      expect(formatWaveRange(3.0, 3.1, meters), '0.9 m');
    });

    test('the size words do not depend on the unit', () {
      // 3 ft is "Moderate" whether it is shown as 3 ft or 0.9 m.
      expect(waveSizeLabel(3), 'Moderate');
    });
  });
}
