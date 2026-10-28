// EC9 / Feature 12: meeting points and shared free hours offline.
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/campus_zones_asset_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/data_sources/meetup_remote_data_source.dart';
import 'package:flutter_front_end/model/dto/marketplace_models.dart';
import 'package:flutter_front_end/model/entities/meeting_point_density.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/impl/meetup_repositories_impl.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/rules/campus_default_zones.dart';
import 'package:flutter_front_end/model/rules/free_slot_expiry.dart';
import 'package:flutter_front_end/model/services/session_owner.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/view_model/meeting_planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// "Now" for every test: Wednesday 16 Sep 2026, 12:00.
final _now = DateTime(2026, 9, 16, 12);

Json _zone(String id, String name) => {
      'id': id,
      'name': name,
      'detail': null,
      'zoneType': 'LIBRARY',
      'isMonitored': true,
      'lat': 4.6,
      'lng': -74.06,
    };

Json _slot(DateTime startsAt, DateTime endsAt) => {
      'startsAt': startsAt.toIso8601String(),
      'endsAt': endsAt.toIso8601String(),
      'sharedBreak': false,
    };

/// Answers with raw JSON like the API, or throws [error] (e.g. no network).
class _FakeMeetupRemote implements MeetupRemoteDataSource {
  Exception? error;
  Object? points = [_zone('server-1', 'Central Library lobby')];
  Object? suggestions = {'slots': [], 'callerHasSchedule': true, 'otherHasSchedule': true};
  int calls = 0;

  Future<Object?> _answer(Object? json) async {
    calls++;
    if (error != null) throw error!;
    return json;
  }

  @override
  Future<Object?> getMeetingPointsJson() => _answer(points);

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async =>
      parseList(await getMeetingPointsJson(), meetingPointFromJson);

  @override
  Future<Object?> getSuggestionsJson(String chatRoomId) => _answer(suggestions);

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async =>
      meetingSuggestionsFromJson(await getSuggestionsJson(chatRoomId) as Json);

  @override
  Future<MeetingProposalEntity> createProposal(Map<String, dynamic> body) => throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> answerProposal(String proposalId, String action) => throw UnimplementedError();

  @override
  Future<List<ScheduleBlockEntity>> getSchedule() => throw UnimplementedError();

  @override
  Future<ScheduleBlockEntity> addScheduleBlock(Map<String, dynamic> body) => throw UnimplementedError();

  @override
  Future<void> removeScheduleBlock(String blockId) => throw UnimplementedError();
}

class _NoLocation implements LocationRepository {
  @override
  Future<GeoPoint?> currentLocation() async => null;
}

class _NoDensity implements MeetingDensityRepository {
  @override
  Future<MeetingPointDensity> getDensity() async => MeetingPointDensity.empty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // rootBundle, for the bundled zones
  sqfliteFfiInit();

  late AppDatabase db;
  late _FakeMeetupRemote remote;
  late SessionOwner owner;

  MeetupRepositoryImpl repository({CampusZonesAssetDataSource? bundled, bool withCache = true}) =>
      MeetupRepositoryImpl(
        remote,
        cache: withCache ? ResponseCache(db) : null,
        owner: owner,
        bundledZones: bundled,
        now: () => _now,
      );

  setUp(() {
    db = AppDatabase.withFactory(databaseFactoryFfi);
    remote = _FakeMeetupRemote();
    owner = SessionOwner()..signedIn('ana-id');
  });

  tearDown(() => db.close());

  group('meeting points: network falling back to cache, then to the bundled file', () {
    test('online, the server answer is returned and saved', () async {
      final points = await repository().getMeetingPoints();

      expect(points.single.id, 'server-1');
      final saved = await ResponseCache(db).read(MeetupRepositoryImpl.meetingPointsOwner, MeetupRepositoryImpl.meetingPointsKey);
      expect(saved, isNotNull);
    });

    test('offline, the saved copy from sqflite is used (a new cache, as after a restart)', () async {
      await repository().getMeetingPoints();
      remote.error = const NetworkException('offline');

      final points = await repository(bundled: CampusZonesAssetDataSource()).getMeetingPoints();

      expect(points.single.id, 'server-1');
    });

    test('offline with nothing saved, the zones in assets/campus_zones.json are used', () async {
      remote.error = const NetworkException('offline');

      final points = await repository(bundled: CampusZonesAssetDataSource()).getMeetingPoints();

      expect(points, hasLength(5));
      expect(points.map((p) => p.name), contains('Mario Laserna lobby'));
      expect(points.every((p) => CampusDefaultZones.isBundled(p.id)), isTrue);
    });

    test('a server failure (5xx) with nothing saved also falls back to the bundled zones', () async {
      remote.error = const ApiException(503, 'down');

      final points = await repository(bundled: CampusZonesAssetDataSource()).getMeetingPoints();

      expect(points, hasLength(5));
    });

    test('without a cache the bundled zones still cover a missing network', () async {
      remote.error = const NetworkException('offline');

      final points = await repository(withCache: false, bundled: CampusZonesAssetDataSource()).getMeetingPoints();

      expect(points, hasLength(5));
    });

    test('offline with nothing saved and no readable file, the user is told there is no connection', () async {
      remote.error = const NetworkException('offline');
      final broken = CampusZonesAssetDataSource(load: () async => throw Exception('missing asset'));

      expect(repository(bundled: broken).getMeetingPoints(), throwsA(isA<NoConnectionException>()));
    });

    test('a client error (401) is not hidden behind the bundled zones', () async {
      remote.error = const ApiException(401, 'expired');

      expect(
        repository(bundled: CampusZonesAssetDataSource()).getMeetingPoints(),
        throwsA(isA<DataException>().having((e) => e is NoConnectionException, 'no connection', isFalse)),
      );
    });

    test('the copy is shared by every account, since campus zones are public', () async {
      await repository().getMeetingPoints();
      owner.signedIn('other-id');
      remote.error = const NetworkException('offline');

      final points = await repository().getMeetingPoints();

      expect(points.single.id, 'server-1');
    });
  });

  group('free times: network falling back to cache, without hours that already ended', () {
    final ended = _slot(DateTime(2026, 9, 16, 9), DateTime(2026, 9, 16, 10));
    final inProgress = _slot(DateTime(2026, 9, 16, 11), DateTime(2026, 9, 16, 13));
    final tomorrow = _slot(DateTime(2026, 9, 17, 10), DateTime(2026, 9, 17, 11));

    test('offline, the saved copy is shown without the slots whose end time passed', () async {
      remote.suggestions = {
        'slots': [ended, inProgress, tomorrow],
        'suggested': ended,
        'callerHasSchedule': true,
        'otherHasSchedule': false,
      };
      await repository().getSuggestions('r1');
      remote.error = const NetworkException('offline');

      final saved = await repository().getSuggestions('r1');

      expect(saved.slots.map((s) => s.endsAt), [DateTime(2026, 9, 16, 13), DateTime(2026, 9, 17, 11)]);
      expect(saved.suggested, isNull, reason: 'the suggested slot already ended');
      expect(saved.otherHasSchedule, isFalse);
    });

    test('a suggested slot that has not ended survives the filter', () async {
      remote.suggestions = {
        'slots': [tomorrow],
        'suggested': tomorrow,
        'callerHasSchedule': true,
        'otherHasSchedule': true,
      };
      await repository().getSuggestions('r1');
      remote.error = const ApiException(500, 'boom');

      final saved = await repository().getSuggestions('r1');

      expect(saved.suggested?.startsAt, DateTime(2026, 9, 17, 10));
    });

    test('online, the server answer is returned as is', () async {
      remote.suggestions = {
        'slots': [tomorrow],
        'callerHasSchedule': true,
        'otherHasSchedule': true,
      };

      final fresh = await repository().getSuggestions('r1');

      expect(fresh.slots, hasLength(1));
    });

    test('offline with nothing saved, the user is told there is no connection', () async {
      remote.error = const NetworkException('offline');

      expect(repository().getSuggestions('r1'), throwsA(isA<NoConnectionException>()));
    });

    test('the copy belongs to one user and one chat', () async {
      remote.suggestions = {
        'slots': [tomorrow],
        'callerHasSchedule': true,
        'otherHasSchedule': true,
      };
      await repository().getSuggestions('r1');
      remote.error = const NetworkException('offline');

      expect(repository().getSuggestions('r2'), throwsA(isA<NoConnectionException>()));
      owner.signedIn('other-id');
      expect(repository().getSuggestions('r1'), throwsA(isA<NoConnectionException>()));
    });
  });

  group('FreeSlotExpiry', () {
    test('a slot ending exactly now has ended', () {
      final slot = FreeSlot(startsAt: DateTime(2026, 9, 16, 11), endsAt: _now, sharedBreak: false);

      expect(FreeSlotExpiry.hasEnded(slot, _now), isTrue);
      expect(FreeSlotExpiry.hasEnded(slot, _now.subtract(const Duration(minutes: 1))), isFalse);
    });
  });

  group('meeting planner offline', () {
    MeetupUseCases useCases(MeetupRepository repo) => MeetupUseCases(
          getMeetingPoints: GetMeetingPointsUseCase(repo),
          getSuggestions: GetMeetingSuggestionsUseCase(repo),
          propose: ProposeMeetingUseCase(repo),
          answer: AnswerMeetingProposalUseCase(repo),
          currentLocation: GetCurrentLocationUseCase(_NoLocation()),
          rankZones: RankSafeZonesUseCase(),
          recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
          getDensity: GetMeetingPointDensityUseCase(_NoDensity()),
        );

    test('shows the bundled zones and the saved hours, but does not send a bundled zone', () async {
      final upcoming = DateTime.now().add(const Duration(days: 1));
      remote.suggestions = {
        'slots': [_slot(upcoming, upcoming.add(const Duration(hours: 1)))],
        'callerHasSchedule': true,
        'otherHasSchedule': true,
      };
      final repo = MeetupRepositoryImpl(
        remote,
        cache: ResponseCache(db),
        owner: owner,
        bundledZones: CampusZonesAssetDataSource(),
      );
      await repo.getSuggestions('r1');
      remote.error = const NetworkException('offline');
      final planner = MeetingPlannerViewModel(useCases: useCases(repo), chatRoomId: 'r1', userId: 'ana-id');

      await planner.load();
      await Future<void>.delayed(Duration.zero);

      expect(planner.error, isNull);
      expect(planner.isLoading, isFalse);
      expect(planner.zones, hasLength(5));
      expect(planner.slots, hasLength(1));
      planner.selectSlot(planner.slots.single);
      final callsBefore = remote.calls;
      expect(await planner.propose(), contains('Connect to the internet'));
      expect(remote.calls, callsBefore, reason: 'nothing was sent with a local zone id');
      planner.dispose();
    });
  });
}
