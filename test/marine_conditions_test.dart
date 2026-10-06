import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';

void main() {
  test('reads waves and the water temperature together', () {
    final marine = MarineConditions.fromJson({
      'current': {'wave_height': 3.084, 'sea_surface_temperature': 25.3},
      'hourly': {
        'wave_height': [3.1, 3.4, 4.2],
      },
    })!;

    expect(marine.waves!.nowFeet, 3.084);
    expect(marine.waves!.next24HoursMaxFeet, 4.2);
    expect(marine.waterTemperatureCelsius, 25.3);
  });

  test('waves without a temperature (Lake Michigan, Puget Sound)', () {
    final marine = MarineConditions.fromJson({
      'current': {'wave_height': 0.9, 'sea_surface_temperature': null},
    })!;

    expect(marine.waves, isNotNull);
    expect(marine.waterTemperatureCelsius, isNull);
  });

  test('a temperature without waves (some bays)', () {
    final marine = MarineConditions.fromJson({
      'current': {'wave_height': null, 'sea_surface_temperature': 21.6},
    })!;

    expect(marine.waves, isNull);
    expect(marine.waterTemperatureCelsius, 21.6);
  });

  test('a whole-number temperature is read as a double', () {
    final marine = MarineConditions.fromJson({
      'current': {'sea_surface_temperature': 20},
    })!;
    expect(marine.waterTemperatureCelsius, 20.0);
  });

  test('neither waves nor a temperature (inland places) gives null', () {
    expect(
      MarineConditions.fromJson({
        'current': {'wave_height': null, 'sea_surface_temperature': null},
      }),
      isNull,
    );
    expect(MarineConditions.fromJson({}), isNull);
  });
}
