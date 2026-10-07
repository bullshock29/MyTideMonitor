import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/widgets/home_button.dart';

/// A tiny screen with an app bar, standing in for any real screen.
Widget _screen(String name, {Widget? next}) => Scaffold(
      appBar: AppBar(title: Text(name), actions: const [HomeButton()]),
      body: Builder(
        builder: (context) => next == null
            ? const SizedBox.shrink()
            : TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => next),
                ),
                child: Text('Go deeper from $name'),
              ),
      ),
    );

void main() {
  testWidgets('goes straight home from several screens deep', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _screen(
                  'One',
                  next: _screen('Two', next: _screen('Three')),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go deeper from One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go deeper from Two'));
    await tester.pumpAndSettle();
    expect(find.text('Three'), findsOneWidget); // three screens deep

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Three'), findsNothing);
    expect(find.text('Open'), findsOneWidget); // back on the first screen
  });
}
