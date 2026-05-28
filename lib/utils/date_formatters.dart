import 'package:intl/intl.dart';

final _displayFmt = DateFormat('d MMM yyyy');

/// Formats a date as "5 Jan 2024" for display in the UI.
String formatDisplayDate(DateTime d) => _displayFmt.format(d);

/// Formats a date as "5/1/2024" for compact display.
String formatShortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Formats a duration as "m:ss" (e.g. "1:05").
String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
