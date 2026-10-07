import 'package:flutter/material.dart';
import 'package:my_tide_monitor/models/marine_conditions.dart';
import 'package:my_tide_monitor/models/prediction.dart';
import 'package:my_tide_monitor/services/settings_service.dart';
import 'package:my_tide_monitor/theme/app_theme.dart';

/// One saved location, as the home screen widgets need it.
class WidgetLocation {
  final String id;

  /// What to call it: the user's own name for it, if they gave it one.
  final String name;

  /// Upcoming (and the most recent past) high and low tides, soonest first.
  /// The widget works out the height right now from these.
  final List<Prediction> extremes;

  /// The waves and water temperature near the location, when they are known.
  /// Null for places the model has nothing trustworthy for (waterways,
  /// inland), or when they couldn't be loaded.
  final MarineConditions? marine;

  WidgetLocation({
    required this.id,
    required this.name,
    required this.extremes,
    this.marine,
  });
}

/// The colors the widget uses in one mode (light or dark), as ARGB numbers.
///
/// They come from the same Material 3 theme the app uses, so the widget
/// matches whichever color (blue, green, orange) is chosen in Settings. The
/// background is the theme's surface color with a little of the theme color
/// mixed in, which is what gives the glass its tint.
Map<String, int> widgetPalette(AppColor color, Brightness brightness) {
  final scheme = buildAppTheme(color, brightness).colorScheme;
  final tint = brightness == Brightness.light ? 0.10 : 0.16;
  final background = Color.alphaBlend(scheme.primary.withValues(alpha: tint), scheme.surface);

  return {
    'background': background.toARGB32(),
    'onSurface': scheme.onSurface.toARGB32(),
    'onSurfaceVariant': scheme.onSurfaceVariant.toARGB32(),
    'accent': scheme.primary.toARGB32(),
    'border': scheme.outline.toARGB32(),
  };
}

/// Everything the widgets need, as plain JSON-ready data. The Android side
/// reads this and does the drawing, and also works out the tide height now
/// each time it redraws, so it stays right between the app's updates.
///
/// Which location a widget shows, and its light or dark look and opacity, are
/// chosen per widget on the Android side, so they are not in here.
///
/// Times are milliseconds since 1970 (UTC), heights are feet, temperatures are
/// degrees Celsius, and colors are ARGB numbers. The widget converts to the
/// chosen units and time format.
Map<String, dynamic> buildWidgetSnapshot({
  required List<WidgetLocation> locations,
  required SettingsService settings,
  required DateTime generatedAt,
}) {
  return {
    'version': 2,
    'generatedAt': generatedAt.toUtc().millisecondsSinceEpoch,
    'heightUnit': settings.heightUnit.name, // "feet" or "meters"
    'temperatureUnit': settings.temperatureUnit.name, // "celsius" or "fahrenheit"
    'use24Hour': settings.timeFormat == TimeFormat.twentyFourHour,
    'palette': {
      'light': widgetPalette(settings.appColor, Brightness.light),
      'dark': widgetPalette(settings.appColor, Brightness.dark),
    },
    'locations': [
      for (final location in locations)
        {
          'id': location.id,
          'name': location.name,
          'extremes': [
            for (final p in location.extremes)
              if (p.type != null)
                [p.time.toUtc().millisecondsSinceEpoch, p.value, p.type],
          ],
          if (location.marine != null) 'marine': _marineJson(location.marine!),
        },
    ],
  };
}

// Only what the widget shows: the waves now (feet) and the water temperature
// (°C), either of which may be missing, and when they were read.
Map<String, dynamic> _marineJson(MarineConditions marine) {
  return {
    'waveFeet': marine.waves?.nowFeet,
    'waterCelsius': marine.waterTemperatureCelsius,
    'readAt': marine.fetchedAt.toUtc().millisecondsSinceEpoch,
  };
}
