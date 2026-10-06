import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/main.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('buildAppTheme', () {
    test('every color gives a different primary color', () {
      final primaries = {
        for (final color in AppColor.values)
          buildAppTheme(color, Brightness.light).colorScheme.primary,
      };
      expect(primaries.length, AppColor.values.length);
    });

    test('light and dark are actually light and dark', () {
      for (final color in AppColor.values) {
        expect(buildAppTheme(color, Brightness.light).brightness, Brightness.light);
        expect(buildAppTheme(color, Brightness.dark).brightness, Brightness.dark);
      }
    });

    test('the colors read as blue, green and orange', () {
      Color primary(AppColor c) => buildAppTheme(c, Brightness.light).colorScheme.primary;
      HSLColor hsl(Color c) => HSLColor.fromColor(c);

      // Hue is the position on the color wheel: red 0, orange ~30, green ~120,
      // blue ~220.
      expect(hsl(primary(AppColor.blue)).hue, inInclusiveRange(200, 250));
      expect(hsl(primary(AppColor.green)).hue, inInclusiveRange(120, 170));
      expect(hsl(primary(AppColor.orange)).hue, inInclusiveRange(15, 45));
    });

    test('light mode has a colored app bar, dark mode does not', () {
      final light = buildAppTheme(AppColor.blue, Brightness.light);
      expect(light.appBarTheme.backgroundColor, light.colorScheme.primary);
      expect(light.appBarTheme.foregroundColor, light.colorScheme.onPrimary);

      final dark = buildAppTheme(AppColor.blue, Brightness.dark);
      expect(dark.appBarTheme.backgroundColor, isNull);
    });
  });

  test('themeModeFor maps each choice', () {
    expect(themeModeFor(AppearanceMode.system), ThemeMode.system);
    expect(themeModeFor(AppearanceMode.light), ThemeMode.light);
    expect(themeModeFor(AppearanceMode.dark), ThemeMode.dark);
  });

  group('the app', () {
    late SettingsService settings;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService();
    });

    // A one-widget "home screen" that shows the theme it ended up with.
    Widget probeApp() => MainApp(
          settings: settings,
          home: Builder(
            builder: (context) => Scaffold(
              body: Text(
                Theme.of(context).brightness.name,
                key: const Key('brightness'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        );

    Color primaryOf(WidgetTester tester) {
      final text = tester.widget<Text>(find.byKey(const Key('brightness')));
      return text.style!.color!;
    }

    testWidgets('starts blue, following the phone (light in tests)', (tester) async {
      await tester.pumpWidget(probeApp());
      expect(find.text('light'), findsOneWidget);
      expect(primaryOf(tester), buildAppTheme(AppColor.blue, Brightness.light).colorScheme.primary);
    });

    testWidgets('changing the color re-themes the app that is already open', (tester) async {
      await tester.pumpWidget(probeApp());

      await settings.setAppColor(AppColor.green);
      await tester.pumpAndSettle();
      expect(primaryOf(tester), buildAppTheme(AppColor.green, Brightness.light).colorScheme.primary);

      await settings.setAppColor(AppColor.orange);
      await tester.pumpAndSettle();
      expect(primaryOf(tester), buildAppTheme(AppColor.orange, Brightness.light).colorScheme.primary);
    });

    testWidgets('dark mode and light mode switch regardless of the phone', (tester) async {
      await tester.pumpWidget(probeApp());

      await settings.setAppearanceMode(AppearanceMode.dark);
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);
      expect(primaryOf(tester), buildAppTheme(AppColor.blue, Brightness.dark).colorScheme.primary);

      await settings.setAppearanceMode(AppearanceMode.light);
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
    });

    testWidgets('system mode follows the phone being set to dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(probeApp());
      expect(find.text('dark'), findsOneWidget);

      // An explicit choice overrides the phone.
      await settings.setAppearanceMode(AppearanceMode.light);
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
    });
  });
}
