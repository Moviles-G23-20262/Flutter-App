const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "just now", "2m ago", "3h ago", "Yesterday", "Sep 12".
String timeAgo(DateTime moment, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(moment.toLocal());
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return shortDate(moment);
}

/// "Sep 12".
String shortDate(DateTime moment) {
  final local = moment.toLocal();
  return '${_months[local.month - 1]} ${local.day}';
}

/// "2:21 PM".
String clockTime(DateTime moment) {
  final local = moment.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "$320.000 COP": Colombian pesos, dot as thousands separator, no cents.
String copPrice(double amount) {
  final digits = amount.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '\$$grouped COP';
}

/// "Wed 16 Sep".
String dayLabel(DateTime moment) {
  final local = moment.toLocal();
  return '${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month - 1]}';
}

/// "09:00", 24-hour clock.
String hourMinute(DateTime moment) {
  final local = moment.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// "10:00 - 11:00".
String timeRange(DateTime start, DateTime end) => '${hourMinute(start)} - ${hourMinute(end)}';

/// "07:30" for 450 minutes after midnight.
String minuteOfDay(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// "Monday" for 1.
String weekdayName(int dayOfWeek) =>
    const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][dayOfWeek - 1];

/// "Today", "Yesterday" or "Wed 16 Sep", for date separators in a chat.
String chatDayLabel(DateTime moment, {DateTime? now}) {
  final local = moment.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final difference = DateTime(today.year, today.month, today.day).difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return dayLabel(local);
}
