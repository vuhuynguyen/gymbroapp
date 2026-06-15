import 'app_time_zone.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// Relative day label for a session row: "Today" / "Yesterday" / an absolute "Mon D" date
/// (e.g. "Jun 1"), appending ", YYYY" when the year differs from today. The weekday already shows
/// in the row's DayBadge avatar, so we never repeat a bare weekday here. Renders in [zone] when given
/// (a coach viewing a trainee's captured zone); the device zone otherwise (a trainee's own data).
String relativeDayLabel(DateTime? d, [String? zone]) {
  if (d == null) return '';
  final local = AppTimeZone.wallClock(d, zone);
  final today = AppTimeZone.wallClock(DateTime.now(), zone);
  final dayOnly = DateTime(local.year, local.month, local.day);
  final todayOnly = DateTime(today.year, today.month, today.day);
  final diff = todayOnly.difference(dayOnly).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base = '${_months[local.month - 1]} ${local.day}';
  return local.year == today.year ? base : '$base, ${local.year}';
}
