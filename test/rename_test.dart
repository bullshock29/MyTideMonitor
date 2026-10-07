import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tide_monitor/models/station.dart';
import 'package:my_tide_monitor/screens/station_detail_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/response_cache.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/widgets/rename_dialog.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _station = Station(
  id: 'pier',
  name: 'Springmaid Pier, Myrtle beach',
  state: 'SC',
  latitude: 33.655,
  longitude: -78.918,
  type: 'R',
);

void main() {
  setUp(() async {
    // The detail screen loads tides, which are saved to the response cache.
    // A widget test can't use real files (they never finish on its fake
    // clock), so use a cache that lives in memory.
    responseCache = MemoryResponseCache();

    SharedPreferences.setMockInitialValues({});
    // These tests use the shared instance, because that is what the screens read.
    await favoritesService.load();
    if (favoritesService.isFavorite(_station.id)) {
      await favoritesService.toggle(_station.id);
    }
    await favoritesService.toggle(_station.id); // make it a favorite
  });

  group('rename dialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRenameDialog(context, _station),
              child: const Text('Rename'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts with the current name and shows the real station', (tester) async {
      await openDialog(tester);

      expect(find.text('Rename location'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Springmaid Pier, Myrtle beach'), findsOneWidget);
      expect(find.text('Station: Springmaid Pier, Myrtle beach'), findsOneWidget);
      expect(find.text('Reset'), findsNothing); // nothing to reset yet
    });

    testWidgets('saving a new name renames the location', (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'The Beach');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Rename location'), findsNothing); // dialog closed
      expect(favoritesService.displayName(_station), 'The Beach');
    });

    testWidgets('pressing done on the keyboard saves too', (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'Beach house');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(favoritesService.displayName(_station), 'Beach house');
    });

    testWidgets('cancel changes nothing', (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'Something else');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(favoritesService.customName(_station.id), isNull);
    });

    testWidgets('clearing the box and saving goes back to the station name', (tester) async {
      await favoritesService.rename(_station, 'The Beach');
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(favoritesService.customName(_station.id), isNull);
    });

    testWidgets('Reset appears for a renamed location and restores the name', (tester) async {
      await favoritesService.rename(_station, 'The Beach');
      await openDialog(tester);

      // The box starts with the current custom name.
      expect(find.widgetWithText(TextField, 'The Beach'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(favoritesService.customName(_station.id), isNull);
    });

    testWidgets('the name box stops at the length limit', (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'y' * 80);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, FavoritesService.maxNameLength);
    });
  });

  group('station detail screen', () {
    Widget app() => SettingsScope(
          settings: SettingsService(),
          child: MaterialApp(home: StationDetailScreen(station: _station)),
        );

    testWidgets('shows the station name until it is renamed, then updates live', (tester) async {
      await tester.pumpWidget(app());

      // The title in the app bar.
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Springmaid Pier, Myrtle beach')), findsOneWidget);

      await favoritesService.rename(_station, 'The Beach');
      await tester.pump();

      expect(find.descendant(of: find.byType(AppBar), matching: find.text('The Beach')), findsOneWidget);
      // The real station is still shown, so you know what you're looking at.
      expect(find.text('Springmaid Pier, Myrtle beach'), findsOneWidget);
    });

    testWidgets('has a rename button only while the station is a favorite', (tester) async {
      await tester.pumpWidget(app());
      expect(find.byTooltip('Rename'), findsOneWidget);

      await favoritesService.toggle(_station.id); // unstar
      await tester.pump();
      expect(find.byTooltip('Rename'), findsNothing);
    });

    testWidgets('the rename button opens the dialog', (tester) async {
      await tester.pumpWidget(app());

      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Rename location'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Our spot');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Our spot')), findsOneWidget);
    });
  });
}
