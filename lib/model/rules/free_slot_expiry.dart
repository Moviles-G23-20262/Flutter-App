import '../entities/meetup_entities.dart';

/// A saved copy of the shared free hours can be days old. Hours that already ended are of no use,
/// so they are dropped before the copy is shown (EC9).
class FreeSlotExpiry {
  const FreeSlotExpiry._();

  /// A slot is over once its end time is not after [now].
  static bool hasEnded(FreeSlot slot, DateTime now) => !slot.endsAt.isAfter(now);

  /// [suggestions] without the slots that ended before [now]. The suggested slot is kept only
  /// while it has not ended.
  static MeetingSuggestions dropEnded(MeetingSuggestions suggestions, DateTime now) {
    final suggested = suggestions.suggested;
    return MeetingSuggestions(
      slots: [for (final slot in suggestions.slots) if (!hasEnded(slot, now)) slot],
      suggested: suggested == null || hasEnded(suggested, now) ? null : suggested,
      callerHasSchedule: suggestions.callerHasSchedule,
      otherHasSchedule: suggestions.otherHasSchedule,
    );
  }
}
