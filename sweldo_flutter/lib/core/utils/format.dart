import 'package:intl/intl.dart';

/// Shortens a Stellar key or hash for display: `GABCD…WXYZ`.
String shortKey(String value, [int edge = 5]) {
  if (value.length <= edge * 2 + 1) return value;
  return '${value.substring(0, edge)}…${value.substring(value.length - edge)}';
}

final DateFormat _dateTime = DateFormat("MMM d, y 'at' h:mm a");
final DateFormat _date = DateFormat('MMM d');
final DateFormat _time = DateFormat('h:mm:ss a');

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());
String formatShortDate(DateTime value) => _date.format(value.toLocal());
String formatTime(DateTime value) => _time.format(value.toLocal());

/// Countdown label matching the React `useCountdown` hook.
String countdownLabel(Duration remaining) {
  final seconds = remaining.inSeconds;
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m ${secs.toString().padLeft(2, '0')}s';
}

String plural(int count, String singular, [String? pluralForm]) =>
    count == 1 ? singular : (pluralForm ?? '${singular}s');
