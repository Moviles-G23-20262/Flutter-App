import '../Entities/meetup_entities.dart';

// All of these throw `DataException` (with a user-presentable message) when the request fails.

abstract class MeetupRepository {
  /// Campus safe zones.
  Future<List<MeetingPointEntity>> getMeetingPoints();

  /// Hours when both people in the chat are free, from their class schedules.
  Future<MeetingSuggestions> getSuggestions(String chatRoomId);

  /// Posts a proposal card in the chat; it replaces an unanswered one.
  Future<MeetingProposalEntity> propose({
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<MeetingProposalEntity> accept(String proposalId);

  Future<MeetingProposalEntity> decline(String proposalId);

  /// The proposer withdraws an unanswered proposal.
  Future<MeetingProposalEntity> withdraw(String proposalId);
}

abstract class ScheduleRepository {
  /// The signed-in user's weekly classes.
  Future<List<ScheduleBlockEntity>> getSchedule();

  Future<ScheduleBlockEntity> add(NewScheduleBlock block);

  Future<void> remove(String blockId);
}

abstract class LocationRepository {
  /// Where the device is, or `null` when location is off or permission was refused.
  Future<GeoPoint?> currentLocation();
}
