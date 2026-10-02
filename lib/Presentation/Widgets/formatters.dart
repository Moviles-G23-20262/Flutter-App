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
