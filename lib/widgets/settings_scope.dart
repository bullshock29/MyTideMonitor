import 'package:flutter/widgets.dart';
import 'package:my_tide_monitor/services/settings_service.dart';

/// Makes the [SettingsService] available to every screen and widget below it,
/// and rebuilds the ones that read it when a setting changes.
///
/// Put it above the whole app, then read the settings in any `build` method:
///
/// ```dart
/// final settings = SettingsScope.of(context);
/// Text(settings.formatHeight(5.4));
/// ```
///
/// Calling `of` is what subscribes a widget to changes. That's why, when the
/// user switches feet to meters on the Settings screen, the home screen's
/// cards update behind it without reloading any data.
class SettingsScope extends InheritedNotifier<SettingsService> {
  const SettingsScope({
    super.key,
    required SettingsService settings,
    required super.child,
  }) : super(notifier: settings);

  static SettingsService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this widget. See main.dart.');
    return scope!.notifier!;
  }
}
