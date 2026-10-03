import '../Entities/meeting_point_density.dart';

abstract class MeetingDensityRepository {
  /// Past activity per meeting point and hour. Never throws: when the analytics
  /// service can't be reached it answers [MeetingPointDensity.empty].
  Future<MeetingPointDensity> getDensity();
}
