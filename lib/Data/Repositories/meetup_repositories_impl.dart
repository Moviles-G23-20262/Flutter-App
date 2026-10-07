import '../../Domain/Entities/meetup_entities.dart';
import '../../Domain/repositories/meetup_repositories.dart';
import '../data_sources/device_location_data_source.dart';
import '../data_sources/meetup_remote_data_source.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

class MeetupRepositoryImpl implements MeetupRepository {
  final MeetupRemoteDataSource remote;

  MeetupRepositoryImpl(this.remote);

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() => guardRequest(remote.getMeetingPoints);

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) =>
      guardRequest(() => remote.getSuggestions(chatRoomId));

  @override
  Future<MeetingProposalEntity> propose({
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) =>
      guardRequest(() => remote.createProposal({
            'chatRoomId': chatRoomId,
            'meetingPointId': meetingPointId,
            'startsAt': startsAt.toUtc().toIso8601String(),
            'endsAt': endsAt.toUtc().toIso8601String(),
          }));

  @override
  Future<MeetingProposalEntity> accept(String proposalId) =>
      guardRequest(() => remote.answerProposal(proposalId, 'accept'));

  @override
  Future<MeetingProposalEntity> decline(String proposalId) =>
      guardRequest(() => remote.answerProposal(proposalId, 'decline'));

  @override
  Future<MeetingProposalEntity> withdraw(String proposalId) =>
      guardRequest(() => remote.answerProposal(proposalId, 'cancel'));
}

class ScheduleRepositoryImpl implements ScheduleRepository {
  final MeetupRemoteDataSource remote;

  ScheduleRepositoryImpl(this.remote);

  @override
  Future<List<ScheduleBlockEntity>> getSchedule() => guardRequest(remote.getSchedule);

  @override
  Future<ScheduleBlockEntity> add(NewScheduleBlock block) => guardRequest(() => remote.addScheduleBlock({
        'dayOfWeek': block.dayOfWeek,
        'startMinute': block.startMinute,
        'endMinute': block.endMinute,
        'label': ?block.label,
      }));

  @override
  Future<void> remove(String blockId) => guardRequest(() => remote.removeScheduleBlock(blockId));
}

class LocationRepositoryImpl implements LocationRepository {
  final DeviceLocationDataSource device;

  LocationRepositoryImpl(this.device);

  @override
  Future<GeoPoint?> currentLocation() async {
    try {
      return await device.currentLocation();
    } on Exception {
      // Walking times are a nice-to-have: without a location the zones are still listed.
      return null;
    }
  }
}
