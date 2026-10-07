import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/widget_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _t(String utc) => DateTime.parse('${utc.replaceFirst(' ', 'T')}Z');

Prediction _high(String utc, double ft) => Prediction(time: _t(utc), value: ft, type: 'H');
Prediction _low(String utc, double ft) => Prediction(time: _t(utc), value: ft, type: 'L');

void main() {
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
  });

  Map<String, dynamic> build(List<WidgetLocation> locations) => buildWidgetSnapshot(
        locations: locations,
        settings: settings,
        generatedAt: _t('2026-10-06 12:00'),
      );

  group('the snapshot', () {
    test('carries the settings the widget needs', () async {
      await settings.setHeightUnit(HeightUnit.meters);
      await settings.setTimeFormat(TimeFormat.twentyFourHour);
      await settings.setTemperatureUnit(TemperatureUnit.celsius);

      final snapshot = build([]);

      expect(snapshot['version'], 2);
      expect(snapshot['heightUnit'], 'meters');
      expect(snapshot['use24Hour'], isTrue);
      expect(snapshot['temperatureUnit'], 'celsius');
      expect(snapshot['generatedAt'], _t('2026-10-06 12:00').millisecondsSinceEpoch);
    });

    test('has the defaults when nothing was changed', () {
      final snapshot = build([]);

      expect(snapshot['heightUnit'], 'feet');
      expect(snapshot['use24Hour'], isFalse);
      expect(snapshot['temperatureUnit'], 'fahrenheit');
      expect(snapshot['locations'], isEmpty);
    });

    test('leaves the look of each widget to the widget itself', () {
      final snapshot = build([]);

      expect(snapshot.containsKey('appearance'), isFalse);
      expect(snapshot.containsKey('opacity'), isFalse);
    });

    test('lists the locations in order with their names', () {
      final snapshot = build([
        WidgetLocation(id: 'b', name: 'The Beach', extremes: []),
        WidgetLocation(id: 'a', name: 'Combination Bridge', extremes: []),
      ]);

      final locations = snapshot['locations'] as List;
      expect(locations.map((l) => l['id']), ['b', 'a']);
      expect(locations.map((l) => l['name']), ['The Beach', 'Combination Bridge']);
    });

    test('encodes each high and low as [time in ms, feet, H or L]', () {
      final snapshot = build([
        WidgetLocation(id: 'a', name: 'A', extremes: [
          _low('2026-10-06 04:38', 0.783),
          _high('2026-10-06 10:08', 3.113),
        ]),
      ]);

      final extremes = (snapshot['locations'] as List).single['extremes'] as List;
      expect(extremes[0], [_t('2026-10-06 04:38').millisecondsSinceEpoch, 0.783, 'L']);
      expect(extremes[1], [_t('2026-10-06 10:08').millisecondsSinceEpoch, 3.113, 'H']);
    });

    test('leaves out predictions that are not a high or a low', () {
      final snapshot = build([
        WidgetLocation(id: 'a', name: 'A', extremes: [
          Prediction(time: _t('2026-10-06 05:00'), value: 2.0), // no type
          _high('2026-10-06 10:08', 3.113),
        ]),
      ]);

      final extremes = (snapshot['locations'] as List).single['extremes'] as List;
      expect(extremes.length, 1);
    });

    test('a location with no tides is still listed', () {
      final snapshot = build([WidgetLocation(id: 'a', name: 'A', extremes: [])]);
      expect((snapshot['locations'] as List).single['extremes'], isEmpty);
    });

    test('carries the waves and water temperature of a location that has them', () {
      final snapshot = build([
        WidgetLocation(
          id: 'a',
          name: 'A',
          extremes: [],
          marine: MarineConditions(
            waves: WaveConditions(nowFeet: 2.4, next24HoursMinFeet: 1, next24HoursMaxFeet: 3),
            waterTemperatureCelsius: 21.5,
            fetchedAt: _t('2026-10-06 11:30'),
          ),
        ),
      ]);

      final marine = (snapshot['locations'] as List).single['marine'] as Map;
      expect(marine['waveFeet'], 2.4);
      expect(marine['waterCelsius'], 21.5);
      expect(marine['readAt'], _t('2026-10-06 11:30').millisecondsSinceEpoch);
    });

    test('has no marine entry for a location without them', () {
      final snapshot = build([WidgetLocation(id: 'a', name: 'A', extremes: [])]);
      expect((snapshot['locations'] as List).single.containsKey('marine'), isFalse);
    });

    test('can be turned into JSON text and back', () {
      final snapshot = build([
        WidgetLocation(id: 'a', name: 'A "quoted" name', extremes: [_high('2026-10-06 10:08', 3.1)]),
      ]);

      final decoded = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      expect((decoded['locations'] as List).single['name'], 'A "quoted" name');
      expect(decoded['palette'], isNotNull);
    });
  });

  group('the colors', () {
    test('there is a light and a dark set, each with everything the widget draws', () {
      final palette = build([])['palette'] as Map<String, dynamic>;

      for (final mode in ['light', 'dark']) {
        final colors = palette[mode] as Map<String, dynamic>;
        expect(colors.keys, containsAll(['background', 'onSurface', 'onSurfaceVariant', 'accent', 'border']));
      }
    });

    test('every color is a solid ARGB number the Android side can read', () {
      final palette = build([])['palette'] as Map<String, dynamic>;

      for (final mode in palette.values) {
        for (final value in (mode as Map<String, dynamic>).values) {
          expect(value, isA<int>());
          expect(value, inInclusiveRange(0xFF000000, 0xFFFFFFFF)); // alpha is FF
        }
      }
    });

    test('light is light and dark is dark', () {
      final palette = build([])['palette'] as Map<String, dynamic>;

      double luminance(int argb) => Color(argb).computeLuminance();
      final light = palette['light'] as Map<String, dynamic>;
      final dark = palette['dark'] as Map<String, dynamic>;

      expect(luminance(light['background'] as int), greaterThan(0.5));
      expect(luminance(dark['background'] as int), lessThan(0.2));
      // Text must stand out from the background in both.
      expect(luminance(light['onSurface'] as int), lessThan(0.2));
      expect(luminance(dark['onSurface'] as int), greaterThan(0.5));
    });

    test('they follow the chosen theme color', () async {
      HSLColor hsl(int argb) => HSLColor.fromColor(Color(argb));

      await settings.setAppColor(AppColor.blue);
      final blue = (build([])['palette'] as Map)['light']['accent'] as int;
      await settings.setAppColor(AppColor.green);
      final green = (build([])['palette'] as Map)['light']['accent'] as int;
      await settings.setAppColor(AppColor.orange);
      final orange = (build([])['palette'] as Map)['light']['accent'] as int;

      expect(hsl(blue).hue, inInclusiveRange(200, 250));
      expect(hsl(green).hue, inInclusiveRange(120, 170));
      expect(hsl(orange).hue, inInclusiveRange(15, 45));
    });

    test('the background carries a tint of the theme color', () async {
      await settings.setAppColor(AppColor.orange);
      final orange = Color((build([])['palette'] as Map)['light']['background'] as int);
      await settings.setAppColor(AppColor.blue);
      final blue = Color((build([])['palette'] as Map)['light']['background'] as int);

      // A warm tint has more red than blue, and a cool tint the opposite.
      expect(orange.r, greaterThan(orange.b));
      expect(blue.b, greaterThan(blue.r));
    });

    test('contrast between text and background is comfortable in both modes', () {
      double contrast(int a, int b) {
        final l1 = Color(a).computeLuminance() + 0.05;
        final l2 = Color(b).computeLuminance() + 0.05;
        return l1 > l2 ? l1 / l2 : l2 / l1;
      }

      for (final color in AppColor.values) {
        for (final brightness in Brightness.values) {
          final p = widgetPalette(color, brightness);
          expect(contrast(p['onSurface']!, p['background']!), greaterThan(7), reason: '$color $brightness text');
          expect(contrast(p['onSurfaceVariant']!, p['background']!), greaterThan(4.5), reason: '$color $brightness secondary text');
          expect(contrast(p['accent']!, p['background']!), greaterThan(3), reason: '$color $brightness accent');
        }
      }
    });
  });
}
