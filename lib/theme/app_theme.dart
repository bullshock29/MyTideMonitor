import 'package:flutter/material.dart';
import 'package:my_tide_monitor/services/settings_service.dart';

/// The color each [AppColor] theme is built from. Material 3 turns one "seed"
/// color into a whole matched set (buttons, backgrounds, text, the chart
/// line...), for both light and dark mode.
const Map<AppColor, Color> appSeedColors = {
  AppColor.blue: Color(0xFF0A6FD1), // ocean blue
  AppColor.green: Color(0xFF1B8A5A), // sea green
  AppColor.orange: Color(0xFFF07A1F), // sunset orange
};

/// The full theme for a color in light or dark mode.
ThemeData buildAppTheme(AppColor color, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: appSeedColors[color]!,
    brightness: brightness,
    // The default palette is muted (blue comes out slate, orange comes out
    // brown). "Vibrant" keeps the colors recognisable.
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: brightness == Brightness.light
        // In light mode the top bar carries the theme color. In dark mode it
        // stays dark, because the dark mode primary is a pale pastel that
        // would glare as a bar.
        ? AppBarTheme(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          )
        : null,
  );
}

/// Flutter's name for the light/dark choice.
ThemeMode themeModeFor(AppearanceMode mode) => switch (mode) {
      AppearanceMode.system => ThemeMode.system,
      AppearanceMode.light => ThemeMode.light,
      AppearanceMode.dark => ThemeMode.dark,
    };
