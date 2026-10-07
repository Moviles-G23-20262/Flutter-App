import '../Entities/meeting_point_density.dart';
import '../Entities/meeting_point_score.dart';
import '../Entities/meetup_entities.dart';
import '../rules/walking_distance.dart';

/// Smart Meeting Point Ranking: scores every safe zone from three signals.
///
///  * distance: how short the user's walk is (0 minutes -> 1, [maxWalkMinutes] or more -> 0).
///  * time suitability: monitored zones suit any hour; a zone without monitoring only suits
///    campus daytime hours.
///  * history: confirmed exchanges at that zone during the meetup hour, relative to the busiest
///    zone at that hour (BQ12). If nobody met at that hour yet, overall activity is used.
///
/// A signal that isn't available (no GPS, no history) is left out and the weights of the
/// others are rescaled, so the ranking still works offline.
class RankMeetingPointsUseCase {
  static const double distanceWeight = 0.5;
  static const double timeWeight = 0.25;
  static const double historyWeight = 0.25;

  /// Score of a zone without monitoring outside daytime hours.
  static const double offHoursScore = 0.3;

  /// A walk this long (or longer) scores 0 for distance: classes only leave ~10 minutes.
  final int maxWalkMinutes;

  /// Campus daytime: [daytimeStartHour] inclusive to [daytimeEndHour] exclusive.
  final int daytimeStartHour;
  final int daytimeEndHour;

  const RankMeetingPointsUseCase({
    this.maxWalkMinutes = 10,
    this.daytimeStartHour = 7,
    this.daytimeEndHour = 18,
  });

  /// Best zone first. [at] is when the meetup would happen (hour in campus local time).
  List<MeetingPointScore> execute({
    required List<MeetingPointEntity> zones,
    GeoPoint? from,
    required DateTime at,
    MeetingPointDensity density = MeetingPointDensity.empty,
  }) {
    final hour = at.hour;
    final daytime = hour >= daytimeStartHour && hour < daytimeEndHour;

    var maxHourly = 0;
    var maxTotal = 0;
    for (final zone in zones) {
      final hourly = density.at(zone.id, hour);
      final total = density.total(zone.id);
      if (hourly > maxHourly) maxHourly = hourly;
      if (total > maxTotal) maxTotal = total;
    }

    final scores = <MeetingPointScore>[];
    for (final zone in zones) {
      final walk = from == null ? null : WalkingDistance.minutes(from, zone.location);
      final double? distance = walk == null ? null : 1 - (walk < maxWalkMinutes ? walk : maxWalkMinutes) / maxWalkMinutes;

      final time = zone.isMonitored || daytime ? 1.0 : offHoursScore;

      final hourly = density.at(zone.id, hour);
      double? history;
      if (maxHourly > 0) {
        history = hourly / maxHourly;
      } else if (maxTotal > 0) {
        history = density.total(zone.id) / maxTotal;
      }

      var weight = timeWeight;
      var sum = timeWeight * time;
      if (distance != null) {
        weight += distanceWeight;
        sum += distanceWeight * distance;
      }
      if (history != null) {
        weight += historyWeight;
        sum += historyWeight * history;
      }

      final label = '${hour.toString().padLeft(2, '0')}:00';
      scores.add(MeetingPointScore(
        zone: zone,
        walkMinutes: walk,
        distance: distance,
        time: time,
        history: history,
        total: sum / weight,
        reasons: [
          if (walk != null) '$walk min walk from you',
          if (zone.isMonitored) 'Monitored by campus security' else if (!daytime) 'Not monitored at this hour',
          if (hourly > 0) 'Popular for exchanges around $label',
        ],
      ));
    }

    scores.sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      if (a.zone.isMonitored != b.zone.isMonitored) return a.zone.isMonitored ? -1 : 1;
      return a.zone.name.compareTo(b.zone.name);
    });
    return scores;
  }
}