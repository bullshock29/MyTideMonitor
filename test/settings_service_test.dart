import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    await settings.load();
  });

  test('defaults suit the US: Fahrenheit, miles, feet, 12-hour', () {
    expect(settings.temperatureUnit, TemperatureUnit.fahrenheit);
    expect(settings.distanceUnit, DistanceUnit.miles);
    expect(settings.heightUnit, HeightUnit.feet);
    expect(settings.timeFormat, TimeFormat.twelveHour);
  });

  test('the theme defaults to blue, following the phone', () {
    expect(settings.appearanceMode, AppearanceMode.system);
    expect(settings.appColor, AppColor.blue);
  });

  group('heights', () {
    test('feet', () {
      expect(settings.formatHeight(5.4), '5.4 ft');
      expect(settings.formatHeight(5.4, decimals: 0), '5 ft');
      expect(settings.heightWord, 'feet');
    });

    test('meters', () async {
      await settings.setHeightUnit(HeightUnit.meters);
      expect(settings.formatHeight(5.4), '1.65 m'); // 5.4 * 0.3048 = 1.646
      expect(settings.formatHeight(10), '3.05 m');
      expect(settings.heightValue(10), closeTo(3.048, 1e-9));
      expect(settings.heightWord, 'meters');
    });

    test('a tiny negative height never prints as -0.0', () {
      expect(settings.formatHeight(-0.04), '0.0 ft');
      expect(settings.formatHeight(-0.6), '-0.6 ft');
    });
  });

  group('distances', () {
    test('miles', () {
      expect(settings.formatDistance(3.04), '3.0 mi');
      expect(settings.formatDistance(50, decimals: 0), '50 mi');
    });

    test('kilometers', () async {
      await settings.setDistanceUnit(DistanceUnit.kilometers);
      expect(settings.formatDistance(3.0), '4.8 km');
      expect(settings.formatDistance(50, decimals: 0), '80 km');
    });
  });

  group('temperatures', () {
    test('Fahrenheit', () {
      expect(settings.formatTemperature(22), '72°F');
      expect(settings.formatTemperature(0), '32°F');
      expect(settings.formatTemperature(25.2, decimals: 1), '77.4°F');
    });

    test('Celsius', () async {
      await settings.setTemperatureUnit(TemperatureUnit.celsius);
      expect(settings.formatTemperature(22), '22°C');
      expect(settings.formatTemperature(25.2, decimals: 1), '25.2°C');
    });
  });

  group('times', () {
    final fourFortyEight = DateTime(2026, 10, 7, 16, 48); // a Wednesday

    // intl may put a narrow no-break space before AM/PM, so match any space.
    test('12-hour', () {
      expect(settings.formatClock(fourFortyEight), matches(RegExp(r'^4:48\s+PM$')));
      expect(settings.formatHour(fourFortyEight), matches(RegExp(r'^4\s+PM$')));
      expect(settings.formatWeekdayClock(fourFortyEight),
          matches(RegExp(r'^Wed 4:48\s+PM$')));
      expect(settings.formatDateClock(fourFortyEight),
          matches(RegExp(r'^Wed, Oct 7 • 4:48\s+PM$')));
    });

    test('24-hour', () async {
      await settings.setTimeFormat(TimeFormat.twentyFourHour);
      expect(settings.formatClock(fourFortyEight), '16:48');
      expect(settings.formatClock(DateTime(2026, 10, 7, 5, 3)), '05:03');
      expect(settings.formatHour(fourFortyEight), '16:00');
      expect(settings.formatWeekdayClock(fourFortyEight), 'Wed 16:48');
      expect(settings.formatDateClock(fourFortyEight), 'Wed, Oct 7 • 16:48');
    });

    test('midnight and noon in 12-hour time', () {
      expect(settings.formatClock(DateTime(2026, 10, 7, 0, 5)),
          matches(RegExp(r'^12:05\s+AM$')));
      expect(settings.formatClock(DateTime(2026, 10, 7, 12, 0)),
          matches(RegExp(r'^12:00\s+PM$')));
    });
  });

  group('saving', () {
    test('choices survive a restart', () async {
      await settings.setTemperatureUnit(TemperatureUnit.celsius);
      await settings.setDistanceUnit(DistanceUnit.kilometers);
      await settings.setHeightUnit(HeightUnit.meters);
      await settings.setTimeFormat(TimeFormat.twentyFourHour);
      await settings.setAppearanceMode(AppearanceMode.dark);
      await settings.setAppColor(AppColor.orange);

      final reloaded = SettingsService();
      await reloaded.load();
      expect(reloaded.temperatureUnit, TemperatureUnit.celsius);
      expect(reloaded.distanceUnit, DistanceUnit.kilometers);
      expect(reloaded.heightUnit, HeightUnit.meters);
      expect(reloaded.timeFormat, TimeFormat.twentyFourHour);
      expect(reloaded.appearanceMode, AppearanceMode.dark);
      expect(reloaded.appColor, AppColor.orange);
    });

    test('an unrecognised saved value falls back to the default', () async {
      SharedPreferences.setMockInitialValues({
        'setting_height_unit': 'furlongs',
        'setting_time_format': 'twentyFourHour',
      });
      final reloaded = SettingsService();
      await reloaded.load();
      expect(reloaded.heightUnit, HeightUnit.feet);
      expect(reloaded.timeFormat, TimeFormat.twentyFourHour);
    });

    test('listeners hear about a change, but not about no change', () async {
      var calls = 0;
      settings.addListener(() => calls++);

      await settings.setHeightUnit(HeightUnit.meters);
      expect(calls, 1);
      await settings.setHeightUnit(HeightUnit.meters); // same value
      expect(calls, 1);
    });
  });
}
