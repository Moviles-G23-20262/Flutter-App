import '../entities/exchange_entity.dart';
import '../entities/user_summary.dart';

/// One open order seen as a meetup, from the signed-in user's side.
class MeetupItem {
  final ExchangeEntity exchange;

  /// The signed-in user is the buyer (only the buyer confirms the exchange).
  final bool isBuyer;

  /// The other student; `null` when the API did not include them.
  final UserSummary? other;

  const MeetupItem({required this.exchange, required this.isBuyer, this.other});

  DateTime? get startsAt => exchange.meetingStartsAt;
  DateTime? get endsAt => exchange.meetingEndsAt;
}

/// The signed-in user's open orders, grouped by what is left to do about the meetup:
///
/// - [upcoming]: a place and time are agreed and the meeting has not ended, soonest first;
/// - [toComplete]: the agreed time is over but nobody confirmed the exchange yet, most recent first;
/// - [notAgreed]: ordered, but no place and time agreed in the chat yet, newest first.
///
/// Completed and cancelled orders are history, not meetups, so they are left out.
class MyMeetups {
  final List<MeetupItem> upcoming;
  final List<MeetupItem> toComplete;
  final List<MeetupItem> notAgreed;

  const MyMeetups({this.upcoming = const [], this.toComplete = const [], this.notAgreed = const []});

  static const MyMeetups empty = MyMeetups();

  bool get isEmpty => upcoming.isEmpty && toComplete.isEmpty && notAgreed.isEmpty;

  /// The next meeting that has not ended, if any.
  MeetupItem? get next => upcoming.isEmpty ? null : upcoming.first;

  factory MyMeetups.from(List<ExchangeEntity> exchanges, {required String userId, required DateTime now}) {
    final upcoming = <MeetupItem>[];
    final toComplete = <MeetupItem>[];
    final notAgreed = <MeetupItem>[];

    for (final e in exchanges) {
      if (!e.isPending) continue;
      final isBuyer = e.buyerId == userId;
      if (!isBuyer && e.sellerId != userId) continue;
      final item = MeetupItem(exchange: e, isBuyer: isBuyer, other: isBuyer ? e.seller : e.buyer);
      final start = e.meetingStartsAt;
      final end = e.meetingEndsAt ?? start;
      if (start == null || end == null) {
        notAgreed.add(item);
      } else if (end.isAfter(now)) {
        upcoming.add(item);
      } else {
        toComplete.add(item);
      }
    }

    upcoming.sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
    toComplete.sort((a, b) => b.startsAt!.compareTo(a.startsAt!));
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    notAgreed.sort((a, b) => (b.exchange.createdAt ?? epoch).compareTo(a.exchange.createdAt ?? epoch));
    return MyMeetups(upcoming: upcoming, toComplete: toComplete, notAgreed: notAgreed);
  }
}
