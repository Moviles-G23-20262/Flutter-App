import 'package:flutter_front_end/Domain/Entities/meeting_point_density.dart';
import 'package:flutter_front_end/Domain/Entities/meetup_entities.dart';
import 'package:flutter_front_end/Domain/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/Domain/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

MeetingPointEntity _zone(String id, double lat, {bool monitored = true}) => MeetingPointEntity(
      id: id,
      name: 'Zone $id',
      zoneType: MeetingZoneTypeEnum.PLAZA,
      isMonitored: monitored,
      location: GeoPoint(lat, -74.065),
    );

// 0.0009 degrees of latitude is about 100 m, i.e. a 2 minute walk.
const _here = GeoPoint(4.6000, -74.065);
final _tenAm = DateTime(2026, 10, 5, 10);
final _elevenPm = DateTime(2026, 10, 5, 23);

void main() {
  const ranker = RankMeetingPointsUseCase();

  group('Smart meeting point ranking', () {
    test('a closer zone beats a farther one when everything else is equal', () {
      final near = _zone('near', 4.6009);
      final far = _zone('far', 4.6063); // about 700 m, a 9 minute walk

      final scores = ranker.execute(zones: [far, near], from: _here, at: _tenAm);

      expect(scores.map((s) => s.zone.id), ['near', 'far']);
      expect(scores.first.walkMinutes, 2);
      expect(scores.first.distance, closeTo(0.8, 1e-9));
      expect(scores.last.distance, closeTo(0.1, 1e-9));
    });

    test('at night a zone without monitoring loses to a monitored one at the same spot', () {
      final monitored = _zone('safe', 4.6009);
      final unmonitored = _zone('open', 4.6009, monitored: false);

      final night = ranker.execute(zones: [unmonitored, monitored], from: _here, at: _elevenPm);
      final day = ranker.execute(zones: [unmonitored, monitored], from: _here, at: _tenAm);

      expect(night.first.zone.id, 'safe');
      expect(night.last.time, RankMeetingPointsUseCase.offHoursScore);
      expect(night.last.reasons, contains('Not monitored at this hour'));
      // By day both suit the hour, so the tie is broken in favour of the monitored one.
      expect(day.map((s) => s.time), [1.0, 1.0]);
      expect(day.first.zone.id, 'safe');
    });

    test('the zone where exchanges usually happen at that hour moves up', () {
      final a = _zone('a', 4.6009);
      final b = _zone('b', 4.6009);
      final density = MeetingPointDensity({
        'a': {10: 1},
        'b': {10: 5},
      });

      final scores = ranker.execute(zones: [a, b], from: _here, at: _tenAm, density: density);

      expect(scores.map((s) => s.zone.id), ['b', 'a']);
      expect(scores.first.history, 1.0);
      expect(scores.last.history, closeTo(0.2, 1e-9));
      expect(scores.first.reasons, contains('Popular for exchanges around 10:00'));
    });

    test('with no activity at that hour, overall activity is used', () {
      final a = _zone('a', 4.6009);
      final b = _zone('b', 4.6009);
      final density = MeetingPointDensity({
        'a': {15: 4},
        'b': {16: 1},
      });

      final scores = ranker.execute(zones: [a, b], from: _here, at: _tenAm, density: density);

      expect(scores.first.zone.id, 'a');
      expect(scores.first.history, 1.0);
    });

    test('without GPS and without history it still ranks, and leaves those signals out', () {
      final scores = ranker.execute(
        zones: [_zone('z', 4.6009, monitored: false), _zone('a', 4.6009)],
        at: _tenAm,
      );

      expect(scores.every((s) => s.distance == null && s.history == null), isTrue);
      expect(scores.every((s) => s.walkMinutes == null), isTrue);
      // Ties go to the monitored zone, then by name.
      expect(scores.map((s) => s.zone.id), ['a', 'z']);
      expect(scores.first.total, 1.0);
    });
  });

  group('Context-aware recommendation', () {
    final recommender = RecommendMeetingPointUseCase(ranker);

    test('marks only the top zone as the best match and carries the reasons', () {
      final result = recommender.execute(
        zones: [_zone('far', 4.6063), _zone('near', 4.6009)],
        from: _here,
        meetingAt: _tenAm,
      );

      expect(result.best?.zone.id, 'near');
      expect(result.ranked.where((r) => r.bestMatch).length, 1);
      expect(result.best?.walkMinutes, 2);
      expect(result.best?.reasons, contains('2 min walk from you'));
      expect(result.best?.score, greaterThan(result.ranked.last.score!));
    });

    test('the hour being planned changes the answer, not just the current time', () {
      final zones = [_zone('open', 4.6009, monitored: false), _zone('safe', 4.6018)];

      final byDay = recommender.execute(zones: zones, from: _here, meetingAt: _tenAm);
      final byNight = recommender.execute(zones: zones, from: _here, meetingAt: _elevenPm);

      expect(byDay.best?.zone.id, 'open'); // closer, and daytime suits it
      expect(byNight.best?.zone.id, 'safe'); // after hours only the monitored zone suits
    });

    test('no zones, no recommendation', () {
      final result = recommender.execute(zones: const [], from: _here, now: _tenAm);

      expect(result.best, isNull);
      expect(result.ranked, isEmpty);
    });
  });
}
