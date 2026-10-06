import 'package:flutter/material.dart';
import 'package:my_tide_monitor/screens/home_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/response_cache.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
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

  runApp(MainApp(settings: settingsService));
}

class MainApp extends StatelessWidget {
  /// The user's settings. Passed in (rather than read from the global) so a
  /// test can supply its own.
  final SettingsService settings;

  /// The first screen. Always [HomeScreen] in the real app.
  final Widget home;

  const MainApp({super.key, required this.settings, this.home = const HomeScreen()});

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
