/// Business rules for selecting a valid upcoming meeting time (never in the past).
class MeetingTimeRules {
  const MeetingTimeRules._();

  /// Step in minutes offered by the time picker (00, 05, …, 55).
  static const int minuteStep = 5;

  /// The earliest selectable start time strictly after [now], rounded up to the next [minuteStep].
  static DateTime earliestStart(DateTime now) {
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final remainder = base.minute % minuteStep;
    final addMinutes = remainder == 0 ? minuteStep : minuteStep - remainder;
    return base.add(Duration(minutes: addMinutes));
  }

  /// Earliest calendar day that still has at least one selectable future time.
  /// If no selectable time remains today (e.g. 23:55+), this advances to tomorrow.
  static DateTime earliestDate(DateTime now) {
    final first = earliestStart(now);
    return DateTime(first.year, first.month, first.day);
  }

  /// Hours (0..23) selectable on [date] relative to [now].
  /// Returns an empty list for past dates; for today, omits hours that have already passed.
  static List<int> availableHours(DateTime date, DateTime now) {
    final target = DateTime(date.year, date.month, date.day);
    final first = earliestStart(now);
    final firstDay = DateTime(first.year, first.month, first.day);
    if (target.isBefore(firstDay)) return const [];
    final startHour = target == firstDay ? first.hour : 0;
    return [for (int h = startHour; h < 24; h++) h];
  }

  /// Minutes (0, 5, …, 55) selectable on [date] at [hour] relative to [now].
  /// Omits any minute at or before [now].
  static List<int> availableMinutes(DateTime date, int hour, DateTime now) {
    final target = DateTime(date.year, date.month, date.day);
    final first = earliestStart(now);
    final firstDay = DateTime(first.year, first.month, first.day);
    if (target.isBefore(firstDay)) return const [];
    if (target == firstDay && hour < first.hour) return const [];
    final startMinute = (target == firstDay && hour == first.hour) ? first.minute : 0;
    return [for (int m = startMinute; m < 60; m += minuteStep) m];
  }

  /// True when [startsAt] is strictly in the future relative to [now].
  static bool isValidStart(DateTime startsAt, DateTime now) => startsAt.isAfter(now);
}
