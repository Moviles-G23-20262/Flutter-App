/// When campus is open for meetups. Same hours the back-end uses for suggestions:
/// Monday to Saturday, 07:00 to 20:00, campus (Bogotá) time.
abstract final class CampusHours {
  static const int opensAtHour = 7;
  static const int closesAtHour = 20;

  /// [DateTime.monday] … [DateTime.saturday].
  static bool isCampusDay(DateTime day) => day.weekday != DateTime.sunday;

  static bool isOpen(DateTime now) =>
      isCampusDay(now) && now.hour >= opensAtHour && now.hour < closesAtHour;

  /// The next time campus opens after [now] (when it is closed).
  static DateTime nextOpening(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (now.hour >= opensAtHour) day = day.add(const Duration(days: 1));
    while (!isCampusDay(day)) {
      day = day.add(const Duration(days: 1));
    }
    return DateTime(day.year, day.month, day.day, opensAtHour);
  }

  /// "tomorrow at 07:00", "today at 07:00" or "on Monday at 07:00".
  static String describeNextOpening(DateTime now) {
    final next = nextOpening(now);
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(next.year, next.month, next.day).difference(today).inDays;
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final when = days == 0 ? 'today' : days == 1 ? 'tomorrow' : 'on ${names[next.weekday - 1]}';
    return '$when at ${opensAtHour.toString().padLeft(2, '0')}:00';
  }
}
