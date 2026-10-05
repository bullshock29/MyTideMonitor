import 'package:flutter/material.dart';
import 'package:my_tide_monitor/screens/menu/noaa_stations_screen.dart';
import 'package:my_tide_monitor/screens/menu/profile_screen.dart';
import 'package:my_tide_monitor/screens/menu/settings_screen.dart';

/// The app's side menu. Put it in the `drawer:` of any Scaffold.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // Closes the drawer and returns to the home screen.
  void _goHome(BuildContext context) {
    Navigator.pop(context);
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // Closes the drawer, returns to home, then opens the chosen screen.
  // Going via home first keeps the back stack from growing as the user
  // moves between menu screens.
  void _open(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('My Tide Monitor', style: TextStyle(fontSize: 24)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => _goHome(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => _open(context, const SettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            onTap: () => _open(context, const ProfileScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.waves),
            title: const Text('NOAA Stations'),
            onTap: () => _open(context, const NoaaStationsScreen()),
          ),
        ],
      ),
    );
  }
}

/// Hamburger button that opens the nearest Scaffold's drawer.
///
/// A Scaffold with a drawer only shows its own hamburger on the first screen;
/// on pushed screens the app bar shows a back arrow instead. Use this as the
/// AppBar's `leading:` to keep the menu reachable.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
