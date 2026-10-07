import 'package:flutter/material.dart';
import 'package:my_tide_monitor/screens/home_screen.dart';
import 'package:my_tide_monitor/screens/station_detail_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/marine_service.dart';
import 'package:my_tide_monitor/services/noaa_service.dart';
import 'package:my_tide_monitor/services/response_cache.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/services/station_repository.dart';
import 'package:my_tide_monitor/services/widget_launch_router.dart';
import 'package:my_tide_monitor/services/widget_platform.dart';
import 'package:my_tide_monitor/services/widget_sync.dart';
import 'package:my_tide_monitor/theme/app_theme.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';

Future<void> main() async {
  // Needed before using plugins (like saved preferences) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await favoritesService.load();
  await settingsService.load();

  // Tidy up saved responses from stations not looked at for two weeks. Not
  // awaited: the app doesn't need to wait for housekeeping to start.
  responseCache.prune(const Duration(days: 14));

  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(MainApp(settings: settingsService, navigatorKey: navigatorKey));

  _setUpHomeScreenWidget(navigatorKey);
}

/// Connects the app to its home screen widgets: keeps their data up to date,
/// and opens a location when it is tapped there.
void _setUpHomeScreenWidget(GlobalKey<NavigatorState> navigatorKey) {
  final platform = ChannelWidgetPlatform();
  final stations = StationRepository();

  // Sends the widgets their data on startup, whenever a location or a setting
  // changes, and each time the app comes back to the screen (which also
  // refreshes the tides for the next two weeks, and the waves and water
  // temperature).
  final sync = WidgetSync(
    favorites: favoritesService,
    settings: settingsService,
    platform: platform,
    loadStations: stations.getStations,
    loadExtremes: (id) async => (await NoaaService().fetchHighLowsAhead(id)).value,
    loadMarine: (station) => MarineService().getConditions(station.latitude, station.longitude),
  )..start();
  AppLifecycleListener(onResume: sync.schedule);

  // Tapping a location in the widget opens its detail screen.
  final router = WidgetLaunchRouter(
    platform: platform,
    loadStations: stations.getStations,
    openStation: (station) async {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      // Back from the detail screen should land on the home screen.
      navigator.popUntil((route) => route.isFirst);
      await navigator.push(
        MaterialPageRoute(builder: (_) => StationDetailScreen(station: station)),
      );
    },
  );
  // Wait for the first screen to exist before opening anything on top of it.
  WidgetsBinding.instance.addPostFrameCallback((_) => router.start());
}

class MainApp extends StatelessWidget {
  /// The user's settings. Passed in (rather than read from the global) so a
  /// test can supply its own.
  final SettingsService settings;

  /// The first screen. Always [HomeScreen] in the real app.
  final Widget home;

  /// Lets code outside a screen (like the widget tap handler) open screens.
  final GlobalKey<NavigatorState>? navigatorKey;

  const MainApp({
    super.key,
    required this.settings,
    this.home = const HomeScreen(),
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    // SettingsScope sits above everything so any screen can read the unit
    // and time settings, and rebuild when they change.
    return SettingsScope(
      settings: settings,
      // The theme comes from the settings too, so the whole app, including
      // the screens already open underneath, changes color the moment the
      // user picks a new one.
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'My Tide Monitor',
          theme: buildAppTheme(settings.appColor, Brightness.light),
          darkTheme: buildAppTheme(settings.appColor, Brightness.dark),
          themeMode: themeModeFor(settings.appearanceMode),
          home: home,
        ),
      ),
    );
  }
}
