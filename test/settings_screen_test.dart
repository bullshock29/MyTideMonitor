import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/screens/menu/settings_screen.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsService settings;

  Future<void> openScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: const MaterialApp(home: SettingsScreen()),
    ));
  }

  testWidgets('shows all four settings with the defaults', (tester) async {
    await openScreen(tester);

    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Time format'), findsOneWidget);

    expect(find.text('Example: 72°F'), findsOneWidget);
    expect(find.textContaining('3.0 mi to a tide station'), findsOneWidget);
    expect(find.textContaining('5.4 ft tide'), findsOneWidget);
  });

  testWidgets('tapping a toggle changes the setting and its example', (tester) async {
    await openScreen(tester);

    await tester.tap(find.text('°C'));
    await tester.pump();
    expect(settings.temperatureUnit, TemperatureUnit.celsius);
    expect(find.text('Example: 22°C'), findsOneWidget);

    await tester.tap(find.text('Kilometers'));
    await tester.pump();
    expect(settings.distanceUnit, DistanceUnit.kilometers);
    expect(find.textContaining('4.8 km to a tide station'), findsOneWidget);

    await tester.tap(find.text('Meters'));
    await tester.pump();
    expect(settings.heightUnit, HeightUnit.meters);
    expect(find.textContaining('1.65 m tide'), findsOneWidget);

    await tester.tap(find.text('24-hour'));
    await tester.pump();
    expect(settings.timeFormat, TimeFormat.twentyFourHour);
    expect(find.text('Example: 16:48'), findsOneWidget);
  });

  testWidgets('tapping the choice that is already selected changes nothing', (tester) async {
    await openScreen(tester);

    await tester.tap(find.text('Miles'));
    await tester.pump();
    expect(settings.distanceUnit, DistanceUnit.miles);
  });
}
