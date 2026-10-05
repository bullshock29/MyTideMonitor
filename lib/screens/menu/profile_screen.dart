import 'package:flutter/material.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('My Profile')),
      drawer: const AppDrawer(),
      body: const SizedBox.shrink(),
    );
  }
}
