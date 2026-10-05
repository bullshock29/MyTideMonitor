import 'package:flutter/material.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Settings')),
      drawer: const AppDrawer(),
      body: const SizedBox.shrink(),
    );
  }
}
