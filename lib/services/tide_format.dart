import 'package:my_tide_monitor/services/settings_service.dart';

/// "4:48 PM" for a time today, "Wed 4:48 PM" for any other day (or "16:48"
/// and "Wed 16:48" with the 24-hour setting).
///
/// [utc] is converted to the device's time zone.
String formatTideTime(DateTime utc, SettingsService settings) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final isToday = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return isToday ? settings.formatClock(local) : settings.formatWeekdayClock(local);
}
