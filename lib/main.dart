import 'package:flutter/material.dart';
import 'package:my_tide_monitor/screens/home_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';

Future<void> main() async {
  // Needed before using plugins (like saved preferences) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await favoritesService.load();
  await settingsService.load();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // SettingsScope sits above everything so any screen can read the unit
    // and time settings, and rebuild when they change.
    return SettingsScope(
      settings: settingsService,
      child: const MaterialApp(
        title: 'My Tide Monitor',
        home: HomeScreen(),
      ),
    );
  }
}
