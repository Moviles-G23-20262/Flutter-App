import '../../Domain/Entities/meeting_point_density.dart';

class MeetingPointDensityModel {
  /// Parses GET /analytics/meeting-points/ (BQ12): one row per meeting point and hour.
  static MeetingPointDensity fromJson(Map<String, dynamic> json) {
    // The service answers `available: false` when its meeting point tables aren't migrated yet.
    if (json['available'] == false) return MeetingPointDensity.empty;

    final byPoint = <String, Map<int, int>>{};
    for (final row in json['data'] as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final hours = byPoint.putIfAbsent(map['meeting_point_id'] as String, () => <int, int>{});
      final hour = map['hour'] as int;
      hours[hour] = (hours[hour] ?? 0) + (map['total'] as int);
    }
    return MeetingPointDensity(byPoint);
  }
}
