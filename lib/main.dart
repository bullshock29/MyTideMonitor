import 'package:flutter/material.dart';
import 'package:my_tide_monitor/screens/home_screen.dart';
import 'package:my_tide_monitor/services/favorites_service.dart';

Future<void> main() async {
  // Needed before using plugins (like saved preferences) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await favoritesService.load();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'My Tide Monitor',
      home: HomeScreen(),
    );
  }
}
