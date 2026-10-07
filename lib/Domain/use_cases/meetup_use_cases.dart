import '../Entities/meetup_entities.dart';
import '../exceptions/data_exceptions.dart';
import '../rules/walking_distance.dart';
import 'get_meeting_point_density_use_case.dart';
import 'meeting_point_recommendation_use_case.dart';
import '../repositories/meetup_repositories.dart';

class GetMeetingPointsUseCase {
  final MeetupRepository repository;
  GetMeetingPointsUseCase(this.repository);

  Future<List<MeetingPointEntity>> execute() => repository.getMeetingPoints();
}

class GetMeetingSuggestionsUseCase {
  final MeetupRepository repository;
  GetMeetingSuggestionsUseCase(this.repository);

  Future<MeetingSuggestions> execute(String chatRoomId) => repository.getSuggestions(chatRoomId);
}

class ProposeMeetingUseCase {
  final MeetupRepository repository;
  ProposeMeetingUseCase(this.repository);

  Future<MeetingProposalEntity> execute({
    required String chatRoomId,
    required MeetingPointEntity zone,
    required FreeSlot slot,
    DateTime? now,
  }) {
    if (!slot.startsAt.isAfter(now ?? DateTime.now())) {
      throw const DataException('That time already passed. Pick another one.');
    }
    return repository.propose(
      chatRoomId: chatRoomId,
      meetingPointId: zone.id,
      startsAt: slot.startsAt,
      endsAt: slot.endsAt,
    );
  }
}

enum ProposalAnswer { accept, decline, withdraw }

class AnswerMeetingProposalUseCase {
  final MeetupRepository repository;
  AnswerMeetingProposalUseCase(this.repository);

  Future<MeetingProposalEntity> execute(String proposalId, ProposalAnswer answer) {
    switch (answer) {
      case ProposalAnswer.accept:
        return repository.accept(proposalId);
      case ProposalAnswer.decline:
        return repository.decline(proposalId);
      case ProposalAnswer.withdraw:
        return repository.withdraw(proposalId);
    }
  }
}

class GetCurrentLocationUseCase {
  final LocationRepository repository;
  GetCurrentLocationUseCase(this.repository);

  Future<GeoPoint?> execute() => repository.currentLocation();
}

/// Orders safe zones by how long the current user would walk to each, and picks the best match:
/// the closest monitored zone. Without a location, monitored zones come first, then by name.
class RankSafeZonesUseCase {
  /// Typical walking pace on campus, in meters per minute.
  static const double walkingMetersPerMinute = WalkingDistance.metersPerMinute;

  List<RankedZone> execute(List<MeetingPointEntity> zones, GeoPoint? from) {
    final ranked = [
      for (final zone in zones)
        RankedZone(zone: zone, walkMinutes: from == null ? null : walkMinutes(from, zone.location)),
    ];
    ranked.sort((a, b) {
      final byWalk = (a.walkMinutes ?? 0).compareTo(b.walkMinutes ?? 0);
      if (byWalk != 0) return byWalk;
      if (a.zone.isMonitored != b.zone.isMonitored) return a.zone.isMonitored ? -1 : 1;
      return a.zone.name.compareTo(b.zone.name);
    });

    final best = ranked.where((r) => r.zone.isMonitored).firstOrNull ?? ranked.firstOrNull;
    return [
      for (final r in ranked)
        RankedZone(zone: r.zone, walkMinutes: r.walkMinutes, bestMatch: identical(r, best)),
    ];
  }

  /// Straight-line distance at walking pace, rounded up; at least one minute.
  static int walkMinutes(GeoPoint from, GeoPoint to) => WalkingDistance.minutes(from, to);

  /// Great-circle (haversine) distance.
  static double distanceMeters(GeoPoint a, GeoPoint b) => WalkingDistance.meters(a, b);
}

class GetScheduleUseCase {
  final ScheduleRepository repository;
  GetScheduleUseCase(this.repository);

  Future<List<ScheduleBlockEntity>> execute() => repository.getSchedule();
}

class AddScheduleBlockUseCase {
  final ScheduleRepository repository;
  AddScheduleBlockUseCase(this.repository);

  Future<ScheduleBlockEntity> execute(NewScheduleBlock block, {List<ScheduleBlockEntity> existing = const []}) {
    if (block.dayOfWeek < 1 || block.dayOfWeek > 7) throw const DataException('Pick a day.');
    if (block.endMinute <= block.startMinute) {
      throw const DataException('A class has to end after it starts.');
    }
    final clash = existing.where((b) =>
        b.dayOfWeek == block.dayOfWeek && b.startMinute < block.endMinute && b.endMinute > block.startMinute);
    if (clash.isNotEmpty) {
      throw DataException('Overlaps with ${clash.first.label ?? 'another class'} on the same day.');
    }
    final label = block.label?.trim();
    return repository.add(NewScheduleBlock(
      dayOfWeek: block.dayOfWeek,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      label: label == null || label.isEmpty ? null : label,
    ));
  }
}

class RemoveScheduleBlockUseCase {
  final ScheduleRepository repository;
  RemoveScheduleBlockUseCase(this.repository);

  Future<void> execute(String blockId) => repository.remove(blockId);
}

/// Everything the meetup screens need, handed to the presentation layer as one bundle.
class MeetupUseCases {
  final GetMeetingPointsUseCase getMeetingPoints;
  final GetMeetingSuggestionsUseCase getSuggestions;
  final ProposeMeetingUseCase propose;
  final AnswerMeetingProposalUseCase answer;
  final GetCurrentLocationUseCase currentLocation;
  final RankSafeZonesUseCase rankZones;
  final RecommendMeetingPointUseCase recommend;
  final GetMeetingPointDensityUseCase getDensity;

  const MeetupUseCases({
    required this.getMeetingPoints,
    required this.getSuggestions,
    required this.propose,
    required this.answer,
    required this.currentLocation,
    required this.rankZones,
    required this.recommend,
    required this.getDensity,
  });
}
