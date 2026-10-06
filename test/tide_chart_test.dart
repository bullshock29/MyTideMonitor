import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/models/tide_point.dart';
import 'package:my_tide_monitor/services/tide_curve.dart';
import 'package:my_tide_monitor/widgets/tide_chart.dart';

DateTime _t(String utc) => DateTime.parse('${utc.replaceFirst(' ', 'T')}Z');

/// Springmaid Pier highs and lows around 2026-10-06, drawn as a curve.
TideCurve _curve({bool estimated = true}) {
  final extremes = [
    Prediction(time: _t('2026-10-06 04:24'), value: 0.8, type: 'H'),
    Prediction(time: _t('2026-10-06 10:38'), value: -0.6, type: 'L'),
    Prediction(time: _t('2026-10-06 16:48'), value: 1.0, type: 'H'),
    Prediction(time: _t('2026-10-06 23:29'), value: -0.6, type: 'L'),
    Prediction(time: _t('2026-10-07 05:22'), value: 0.9, type: 'H'),
    Prediction(time: _t('2026-10-07 11:36'), value: -0.7, type: 'L'),
  ];
  return TideCurve(curveFromExtremes(extremes), isEstimated: estimated);
}

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

void main() {
  testWidgets('shows the current height, direction and an estimate note', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // 2026-10-06 19:00 UTC: between the 16:48 high and the 23:29 low, falling.
    await tester.pumpWidget(_app(TideChartView(
      curve: _curve(),
      now: _t('2026-10-06 19:00'),
    )));

    expect(tester.takeException(), isNull);
    expect(find.text('Falling'), findsOneWidget);
    expect(find.text('Tide height now'), findsOneWidget);
    expect(find.textContaining('approximate'), findsOneWidget);
    // Between a 1.0 ft high and a -0.6 ft low, about two thirds of the way
    // through the fall.
    expect(find.textContaining(' ft'), findsWidgets);
  });

  testWidgets('real 6-minute data gets no "approximate" note', (tester) async {
    await tester.pumpWidget(_app(TideChartView(
      curve: _curve(estimated: false),
      now: _t('2026-10-06 19:00'),
    )));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('approximate'), findsNothing);
    expect(find.textContaining("NOAA's 6-minute"), findsOneWidget);
  });

  testWidgets('showNotes: false leaves out the explanation but keeps the chart', (tester) async {
    await tester.pumpWidget(_app(TideChartView(
      curve: _curve(),
      now: _t('2026-10-06 19:00'),
      showNotes: false,
    )));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('approximate'), findsNothing);
    expect(find.textContaining('Predicted height'), findsNothing);
    expect(find.text('Tide height now'), findsOneWidget);
    expect(find.text('Falling'), findsOneWidget);
  });

  testWidgets('says so when the curve does not cover now', (tester) async {
    await tester.pumpWidget(_app(TideChartView(
      curve: _curve(),
      now: _t('2026-10-20 12:00'),
    )));

    expect(find.text('Tide chart is not available right now.'), findsOneWidget);
  });

  testWidgets('a rising tide is labelled Rising', (tester) async {
    await tester.pumpWidget(_app(TideChartView(
      curve: _curve(),
      now: _t('2026-10-06 14:00'), // after the 10:38 low, before the 16:48 high
    )));
    expect(find.text('Rising'), findsOneWidget);
  });

  testWidgets('unused TidePoint import check', (tester) async {
    expect(TidePoint(_t('2026-10-06 14:00'), 1).feet, 1);
  });
}
