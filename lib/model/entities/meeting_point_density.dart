import 'package:flutter/foundation.dart';

/// How many exchanges were confirmed at each meeting point, per hour of the campus day (BQ12).
@immutable
class MeetingPointDensity {
  /// meetingPointId -> (hour 0..23 -> confirmed exchanges)
  final Map<String, Map<int, int>> _byPoint;

  const MeetingPointDensity(this._byPoint);

  /// No history available (analytics service down, or no exchanges yet).
  static const empty = MeetingPointDensity({});

  bool get isEmpty => _byPoint.isEmpty;

  /// Exchanges confirmed at [pointId] during [hour].
  int at(String pointId, int hour) => _byPoint[pointId]?[hour] ?? 0;

  /// Exchanges confirmed at [pointId] across the whole day.
  int total(String pointId) => (_byPoint[pointId]?.values ?? const <int>[]).fold(0, (a, b) => a + b);
}
