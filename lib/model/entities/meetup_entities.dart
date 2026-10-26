import 'package:flutter/foundation.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Meetups: where and when buyer and seller meet on campus.
// ──────────────────────────────────────────────────────────────────────────────

/// A latitude/longitude pair.
@immutable
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

enum MeetingZoneTypeEnum {
  LIBRARY,
  STUDENT_CENTER,
  BUILDING_LOBBY,
  PLAZA;

  String get displayName {
    switch (this) {
      case MeetingZoneTypeEnum.LIBRARY:
        return 'Library';
      case MeetingZoneTypeEnum.STUDENT_CENTER:
        return 'Student center';
      case MeetingZoneTypeEnum.BUILDING_LOBBY:
        return 'Building lobby';
      case MeetingZoneTypeEnum.PLAZA:
        return 'Plaza';
    }
  }
}

/// A public campus spot suggested for meetups ("safe zone").
@immutable
class MeetingPointEntity {
  final String id;
  final String name;
  final String? detail;
  final MeetingZoneTypeEnum zoneType;

  /// Covered by campus security cameras or staff.
  final bool isMonitored;
  final GeoPoint location;

  const MeetingPointEntity({
    required this.id,
    required this.name,
    this.detail,
    required this.zoneType,
    required this.isMonitored,
    required this.location,
  });

  @override
  bool operator ==(Object other) => other is MeetingPointEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum MeetingProposalStatusEnum { PENDING, ACCEPTED, DECLINED, CANCELLED }

/// A place and time one side of a chat proposed; the other side accepts or declines it.
@immutable
class MeetingProposalEntity {
  final String id;
  final String chatRoomId;
  final String proposerId;
  final MeetingPointEntity? meetingPoint;
  final DateTime startsAt;
  final DateTime endsAt;
  final MeetingProposalStatusEnum status;

  const MeetingProposalEntity({
    required this.id,
    required this.chatRoomId,
    required this.proposerId,
    this.meetingPoint,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  bool get isPending => status == MeetingProposalStatusEnum.PENDING;
  bool get isAccepted => status == MeetingProposalStatusEnum.ACCEPTED;

  @override
  bool operator ==(Object other) => other is MeetingProposalEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// An hour when both people in a chat are free.
@immutable
class FreeSlot {
  final DateTime startsAt;
  final DateTime endsAt;

  /// Both have class before and after it that day, so both are on campus anyway.
  final bool sharedBreak;

  const FreeSlot({required this.startsAt, required this.endsAt, required this.sharedBreak});

  @override
  bool operator ==(Object other) =>
      other is FreeSlot && other.startsAt == startsAt && other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(startsAt, endsAt);
}

/// What the Campus Guardian found for a chat: shared free hours from both class schedules.
@immutable
class MeetingSuggestions {
  final List<FreeSlot> slots;
  final FreeSlot? suggested;
  final bool callerHasSchedule;
  final bool otherHasSchedule;

  const MeetingSuggestions({
    required this.slots,
    this.suggested,
    required this.callerHasSchedule,
    required this.otherHasSchedule,
  });
}

/// One recurring class in the user's week, in campus time.
@immutable
class ScheduleBlockEntity {
  final String id;

  /// 1 = Monday … 7 = Sunday.
  final int dayOfWeek;

  /// Minutes after midnight.
  final int startMinute;
  final int endMinute;
  final String? label;

  const ScheduleBlockEntity({
    required this.id,
    required this.dayOfWeek,
    required this.startMinute,
    required this.endMinute,
    this.label,
  });

  @override
  bool operator ==(Object other) => other is ScheduleBlockEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A class to add to the schedule.
@immutable
class NewScheduleBlock {
  final int dayOfWeek;
  final int startMinute;
  final int endMinute;
  final String? label;

  const NewScheduleBlock({
    required this.dayOfWeek,
    required this.startMinute,
    required this.endMinute,
    this.label,
  });
}

/// A safe zone with the current user's estimated walk to it.
@immutable
class RankedZone {
  final MeetingPointEntity zone;

  /// `null` when the user's location is unknown.
  final int? walkMinutes;

  /// The zone the app recommends: the highest score (distance, hour and past activity).
  final bool bestMatch;

  /// 0..1 combined score, when the zone was ranked by [RankMeetingPointsUseCase].
  final double? score;

  /// Why it ranks here, e.g. "4 min walk from you".
  final List<String> reasons;

  const RankedZone({
    required this.zone,
    this.walkMinutes,
    this.bestMatch = false,
    this.score,
    this.reasons = const [],
  });
}
