import 'package:intl/intl.dart';

/// "4:48 PM" for a time today, "Wed 4:48 PM" for any other day.
///
/// [utc] is converted to the device's time zone.
String formatTideTime(DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final isToday = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return DateFormat(isToday ? 'h:mm a' : 'EEE h:mm a').format(local);
}
