import '../Entities/meeting_point_density.dart';
import '../Entities/meetup_entities.dart';
import 'rank_meeting_points_use_case.dart';

class MeetingPointRecommendation {
  /// Best match first; only the first one has [RankedZone.bestMatch] set.
  final List<RankedZone> ranked;

  const MeetingPointRecommendation(this.ranked);

  RankedZone? get best => ranked.isEmpty ? null : ranked.first;
}

/// Context-Aware Meeting Point Recommendation: picks the zone that suits the moment, using
/// where the user is, the hour of the meetup and how busy each zone has been at that hour.
class RecommendMeetingPointUseCase {
  final RankMeetingPointsUseCase ranker;

  RecommendMeetingPointUseCase(this.ranker);

  /// [meetingAt] is the hour being planned; without one the recommendation is for [now].
  MeetingPointRecommendation execute({
    required List<MeetingPointEntity> zones,
    GeoPoint? from,
    DateTime? meetingAt,
    DateTime? now,
    MeetingPointDensity density = MeetingPointDensity.empty,
  }) {
    final scores = ranker.execute(
      zones: zones,
      from: from,
      at: meetingAt ?? now ?? DateTime.now(),
      density: density,
    );
    return MeetingPointRecommendation([
      for (var i = 0; i < scores.length; i++)
        RankedZone(
          zone: scores[i].zone,
          walkMinutes: scores[i].walkMinutes,
          bestMatch: i == 0,
          score: scores[i].total,
          reasons: scores[i].reasons,
        ),
    ]);
  }
}
