import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/tide_point.dart';
import 'package:my_tide_monitor/models/wave_conditions.dart';
import 'package:my_tide_monitor/services/response_cache.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/tide_curve.dart';
import 'package:my_tide_monitor/services/tide_format.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';
import 'package:my_tide_monitor/widgets/station_tides.dart';
import 'package:my_tide_monitor/widgets/station_waves.dart';
import 'package:my_tide_monitor/widgets/tide_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_predictions.dart';

DateTime _t(String utc) => DateTime.parse('${utc.replaceFirst(' ', 'T')}Z');

Widget _app(Widget child) => SettingsScope(
      settings: SettingsService(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
      ),
    );

MarineConditions _marine({DateTime? savedAt}) => MarineConditions(
      waves: WaveConditions(nowFeet: 3.0, next24HoursMinFeet: 2.0, next24HoursMaxFeet: 4.0),
      waterTemperatureCelsius: 25,
      fetchedAt: savedAt,
      fromCache: savedAt != null,
    );

TideCurve _curve({DateTime? savedAt}) {
  final extremes = [
    Prediction(time: _t('2026-10-06 10:38'), value: -0.6, type: 'L'),
    Prediction(time: _t('2026-10-06 16:48'), value: 1.0, type: 'H'),
    Prediction(time: _t('2026-10-06 23:29'), value: -0.6, type: 'L'),
  ];
  return TideCurve(
    curveFromExtremes(extremes),
    isEstimated: true,
    fetchedAt: savedAt,
    fromCache: savedAt != null,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('formatAge', () {
    test('plain words for how long ago', () {
      expect(formatAge(const Duration(seconds: 20)), 'just now');
      expect(formatAge(Duration.zero), 'just now');
      expect(formatAge(const Duration(minutes: 1)), '1 min ago');
      expect(formatAge(const Duration(minutes: 45)), '45 min ago');
      expect(formatAge(const Duration(minutes: 59, seconds: 59)), '59 min ago');
      expect(formatAge(const Duration(hours: 1)), '1 h ago');
      expect(formatAge(const Duration(hours: 3, minutes: 40)), '3 h ago');
      expect(formatAge(const Duration(hours: 23, minutes: 59)), '23 h ago');
      expect(formatAge(const Duration(days: 1)), '1 day ago');
      expect(formatAge(const Duration(days: 3, hours: 5)), '3 days ago');
    });

    test('a time slightly in the future (a clock that is a bit off) reads as just now', () {
      expect(formatAge(const Duration(seconds: -30)), 'just now');
    });
  });

  group('wave line', () {
    testWidgets('fresh data shows no offline label', (tester) async {
      await tester.pumpWidget(_app(StationWaves(marine: Future.value(_marine()))));
      await tester.pumpAndSettle();

      expect(find.textContaining('Waves 3 ft'), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('a saved copy says how old it is', (tester) async {
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3, minutes: 10));
      await tester.pumpWidget(_app(StationWaves(marine: Future.value(_marine(savedAt: threeHoursAgo)))));
      await tester.pumpAndSettle();

      expect(find.textContaining('Waves 3 ft'), findsOneWidget); // still shown
      expect(find.text('Offline • as of 3 h ago'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('the offline label stays on the quick-glance home screen', (tester) async {
      final saved = DateTime.now().subtract(const Duration(minutes: 40));
      await tester.pumpWidget(_app(StationWaves(
        marine: Future.value(_marine(savedAt: saved)),
        showNotes: false, // as on the home screen
      )));
      await tester.pumpAndSettle();

      expect(find.text('Offline • as of 40 min ago'), findsOneWidget);
      expect(find.textContaining('Open-water estimate'), findsNothing); // notes are off
    });
  });

  group('tide chart', () {
    final now = _t('2026-10-06 19:00');

    testWidgets('a saved water temperature says how old it is', (tester) async {
      await tester.pumpWidget(_app(TideChartView(
        curve: _curve(),
        now: now,
        waterTemperatureCelsius: 22,
        waterTemperatureSavedAt: now.subtract(const Duration(hours: 2, minutes: 5)),
      )));

      expect(find.text('72°F'), findsOneWidget);
      expect(find.text('Water temp • 2 h ago'), findsOneWidget);
    });

    testWidgets('a fresh water temperature has no age', (tester) async {
      await tester.pumpWidget(_app(TideChartView(
        curve: _curve(),
        now: now,
        waterTemperatureCelsius: 22,
      )));

      expect(find.text('Water temp'), findsOneWidget);
    });

    testWidgets('a saved curve explains it in the note under the chart', (tester) async {
      await tester.pumpWidget(_app(TideChartView(
        curve: _curve(savedAt: now.subtract(const Duration(hours: 5))),
        now: now,
      )));

      expect(find.textContaining('Offline: showing predictions saved 5 h ago.'), findsOneWidget);
      // The chart itself is still drawn from it.
      expect(find.text('Tide height now'), findsOneWidget);
    });

    testWidgets('a live curve has no offline note', (tester) async {
      await tester.pumpWidget(_app(TideChartView(curve: _curve(), now: now)));
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('the saved-copy note is left out where notes are off (home screen)', (tester) async {
      await tester.pumpWidget(_app(TideChartView(
        curve: _curve(savedAt: now.subtract(const Duration(hours: 5))),
        now: now,
        showNotes: false,
      )));

      expect(find.textContaining('Offline'), findsNothing);
      expect(find.text('Tide height now'), findsOneWidget);
    });
  });

  group('tide times', () {
    // These tests make the (fake) internet fail with HTTP 400, as flutter
    // test does for every request, so whatever is in the cache is what shows.
    testWidgets('with no signal, saved predictions show with a note on the detail screen', (tester) async {
      final cache = MemoryResponseCache();
      responseCache = cache;
      await cache.save(
        'noaa-hilo-8661070',
        hiloResponse(DateTime.now().toUtc()),
        savedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 20)),
      );

      await tester.pumpWidget(_app(const StationTides(stationId: '8661070')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Next high'), findsOneWidget); // the tiles still show
      expect(find.textContaining('Offline: showing predictions saved 4 h ago.'), findsOneWidget);
    });

    testWidgets('without notes (home screen) the tides show with no offline text', (tester) async {
      final cache = MemoryResponseCache();
      responseCache = cache;
      await cache.save('noaa-hilo-8661070', hiloResponse(DateTime.now().toUtc()));

      await tester.pumpWidget(_app(const StationTides(stationId: '8661070', showNotes: false)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Next high'), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('with no signal and nothing saved, it offers to try again', (tester) async {
      responseCache = MemoryResponseCache();

      await tester.pumpWidget(_app(const StationTides(stationId: '8661070')));
      await tester.pumpAndSettle();

      expect(find.text('Could not load tide times.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
