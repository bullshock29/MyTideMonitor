import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/place.dart';
import 'package:my_tide_monitor/screens/place_tides_screen.dart';
import 'package:my_tide_monitor/services/geocoding_service.dart';
import 'package:my_tide_monitor/services/location_service.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';
import 'package:my_tide_monitor/widgets/home_button.dart';

/// Find a location: search for a city or place by name, or use the phone's
/// current location. Either way, the next screen picks the tide station.
class FindByCityScreen extends StatefulWidget {
  const FindByCityScreen({super.key});

  @override
  State<FindByCityScreen> createState() => _FindByCityScreenState();
}

class _FindByCityScreenState extends State<FindByCityScreen> {
  final _geocoding = GeocodingService();
  final _location = LocationService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  // True while waiting for the phone to report its location.
  bool _locating = false;

  // Incremented for each search so a slow, older response can't overwrite
  // the results of a newer search.
  int _searchId = 0;

  bool _loading = false;
  String? _error;
  List<Place>? _places; // null until the first search finishes

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Waits until the user pauses typing before calling the network.
  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.length < 2) {
      _searchId++;
      setState(() {
        _places = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_searchId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final places = await _geocoding.search(query);
      if (!mounted || id != _searchId) return;
      setState(() {
        _places = places;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _error = 'Could not search. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);

    try {
      final coordinates = await _location.getCurrentCoordinates();
      if (!mounted) return;

      final place = Place(
        name: 'Your location',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaceTidesScreen(place: place)),
      );
    } on LocationException catch (e) {
      if (!mounted) return;

      // Some problems can only be fixed in the phone's settings.
      final canOpenSettings = e.problem == LocationProblem.servicesOff ||
          e.problem == LocationProblem.deniedForever;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: canOpenSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () => _location.openSettingsFor(e.problem),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Find a Location'),
        actions: const [HomeButton()],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search for a city or place',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();
                      _onChanged('');
                    },
                  ),
              ],
              onChanged: (value) {
                _onChanged(value);
                setState(() {}); // shows or hides the clear button
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _locating ? 'Finding your location…' : 'Use my current location',
                ),
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Message(icon: Icons.wifi_off, text: _error!);
    }

    final places = _places;
    if (places == null) {
      return const _Message(
        icon: Icons.location_city,
        text: 'Type a city or place name, like "Cape May".\n'
            "We'll find the tide stations nearest to it.",
      );
    }

    if (places.isEmpty) {
      return const _Message(
        icon: Icons.search_off,
        text: 'No places found. Try just the city name, '
            'without the state.',
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return ListTile(
          leading: const Icon(Icons.place),
          title: Text(place.name),
          subtitle: Text(place.locationDetail),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlaceTidesScreen(place: place)),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
