import 'package:flutter/foundation.dart';
import 'meetup_entities.dart';

/// Why a meeting point ranks where it does. Every component is 0..1, higher is better.
@immutable
class MeetingPointScore {
  final MeetingPointEntity zone;

  /// `null` when the user's location is unknown.
  final int? walkMinutes;

  /// Closeness to the user. `null` when the user's location is unknown.
  final double? distance;

  /// How well the zone suits the hour of the meetup (monitored zones suit any hour).
  final double time;

  /// How often exchanges happen here at that hour. `null` when there is no history.
  final double? history;

  /// Weighted mix of the components that are available.
  final double total;

  /// Short, user-presentable explanations.
  final List<String> reasons;

  const MeetingPointScore({
    required this.zone,
    required this.walkMinutes,
    required this.distance,
    required this.time,
    required this.history,
    required this.total,
    this.reasons = const [],
  });
}
