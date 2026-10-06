import 'package:flutter/material.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/theme/app_theme.dart';
import 'package:my_tide_monitor/widgets/app_drawer.dart';
import 'package:my_tide_monitor/widgets/home_button.dart';
import 'package:my_tide_monitor/widgets/settings_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reading the settings here makes the screen rebuild when one changes,
    // so each example below updates as soon as a toggle is tapped.
    final settings = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Settings'),
        actions: const [HomeButton()],
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Appearance'),
          _ToggleSetting<AppearanceMode>(
            title: 'Mode',
            note: 'System follows your phone\'s light or dark setting.',
            value: settings.appearanceMode,
            options: const {
              AppearanceMode.system: 'System',
              AppearanceMode.light: 'Light',
              AppearanceMode.dark: 'Dark',
            },
            icons: const {
              AppearanceMode.system: Icon(Icons.brightness_auto),
              AppearanceMode.light: Icon(Icons.light_mode),
              AppearanceMode.dark: Icon(Icons.dark_mode),
            },
            onChanged: settings.setAppearanceMode,
          ),
          _ToggleSetting<AppColor>(
            title: 'Color',
            note: 'Used for the app bar, buttons, and the tide chart.',
            value: settings.appColor,
            options: const {
              AppColor.blue: 'Blue',
              AppColor.green: 'Green',
              AppColor.orange: 'Orange',
            },
            // A dot in each color, so the choices can be told apart at a
            // glance.
            icons: {
              for (final entry in appSeedColors.entries)
                entry.key: Icon(Icons.circle, color: entry.value),
            },
            onChanged: settings.setAppColor,
          ),
          const Divider(),
          _SectionHeader('Units'),
          _ToggleSetting<TemperatureUnit>(
            title: 'Temperature',
            example: 'Example: ${settings.formatTemperature(22)}',
            value: settings.temperatureUnit,
            options: const {
              TemperatureUnit.celsius: '°C',
              TemperatureUnit.fahrenheit: '°F',
            },
            onChanged: settings.setTemperatureUnit,
          ),
          _ToggleSetting<DistanceUnit>(
            title: 'Distance',
            example: 'Example: ${settings.formatDistance(3.0)} to a tide station',
            value: settings.distanceUnit,
            options: const {
              DistanceUnit.kilometers: 'Kilometers',
              DistanceUnit.miles: 'Miles',
            },
            onChanged: settings.setDistanceUnit,
          ),
          _ToggleSetting<HeightUnit>(
            title: 'Height',
            example: 'Example: ${settings.formatHeight(5.4)} tide, '
                '${settings.formatHeight(3)} waves',
            value: settings.heightUnit,
            options: const {
              HeightUnit.feet: 'Feet',
              HeightUnit.meters: 'Meters',
            },
            onChanged: settings.setHeightUnit,
          ),
          const Divider(),
          _SectionHeader('Time'),
          _ToggleSetting<TimeFormat>(
            title: 'Time format',
            example: 'Example: ${settings.formatClock(DateTime(2026, 10, 6, 16, 48))}',
            value: settings.timeFormat,
            options: const {
              TimeFormat.twelveHour: '12-hour',
              TimeFormat.twentyFourHour: '24-hour',
            },
            onChanged: settings.setTimeFormat,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// A setting with exactly two choices, shown as a toggle with the current
/// choice highlighted, and a line below showing what it looks like.
class _ToggleSetting<T> extends StatelessWidget {
  final String title;

  /// A line showing what the setting looks like, like "Example: 72°F".
  /// Used by the unit settings.
  final String? example;

  /// A line explaining the setting, for ones with nothing to show as an
  /// example.
  final String? note;
  final T value;

  /// The choices, in order, with the text for each button.
  final Map<T, String> options;

  /// An optional icon for each choice, shown beside its text.
  final Map<T, Widget>? icons;
  final ValueChanged<T> onChanged;

  const _ToggleSetting({
    required this.title,
    this.example,
    this.note,
    required this.value,
    required this.options,
    this.icons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final option in options.entries)
                  ButtonSegment<T>(
                    value: option.key,
                    label: Text(option.value),
                    icon: icons?[option.key],
                  ),
              ],
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
          if (example != null || note != null) ...[
            const SizedBox(height: 4),
            Text(example ?? note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
