import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/core/cache/map_tile_cache_manager.dart';
import 'package:flutter_front_end/model/data_sources/meetup_remote_data_source.dart';
import 'package:flutter_front_end/model/dto/marketplace_models.dart';
import 'package:flutter_front_end/model/entities/meeting_point_density.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/impl/meetup_repositories_impl.dart';
import 'package:flutter_front_end/model/services/session_owner.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/view/widgets/cached_tile_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 27, 10);

Json _slot(DateTime startsAt) => {
      'startsAt': startsAt.toIso8601String(),
      'endsAt': startsAt.add(const Duration(hours: 1)).toIso8601String(),
      'sharedBreak': true,
    };

/// Counts how many times each chat's free hours were asked to the server.
/// Stands in for the disk cache, which needs the phone's folders.
class _FakeCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _CountingRemote implements MeetupRemoteDataSource {
  final Map<String, int> callsPerChat = {};
  Exception? error;
  List<DateTime> starts = [_now.add(const Duration(hours: 2))];

  int get calls => callsPerChat.values.fold(0, (a, b) => a + b);

  @override
  Future<Object?> getSuggestionsJson(String chatRoomId) async {
    callsPerChat[chatRoomId] = (callsPerChat[chatRoomId] ?? 0) + 1;
    if (error != null) throw error!;
    return {
      'slots': [for (final s in starts) _slot(s)],
      'callerHasSchedule': true,
      'otherHasSchedule': true,
    };
  }

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async =>
      meetingSuggestionsFromJson(await getSuggestionsJson(chatRoomId) as Json);

  @override
  Future<MeetingProposalEntity> createProposal(Map<String, dynamic> body) async =>
      throw const ApiException(400, 'refused in this test');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

MeetingPointEntity _zone(String id, {required bool monitored, required double lat}) => MeetingPointEntity(
      id: id,
      name: 'Zone $id',
      zoneType: MeetingZoneTypeEnum.values.first,
      isMonitored: monitored,
      location: GeoPoint(lat, -74.065),
    );

void main() {
  // ─── L2 · Meeting suggestions LRU ───────────────────────────────────────────

  group('Free hours LRU (MeetupRepositoryImpl)', () {
    late _CountingRemote remote;
    late DateTime now;
    late MeetupRepositoryImpl repo;

    setUp(() {
      remote = _CountingRemote();
      now = _now;
      repo = MeetupRepositoryImpl(remote, owner: SessionOwner()..signedIn('ana'), now: () => now);
    });

    test('reopening the planner for the same chat does not ask the server again', () async {
      final first = await repo.getSuggestions('chat-1');
      final second = await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-1'], 1);
      expect(second.slots, first.slots);
    });

    test('after two minutes the free hours are asked again (schedules can change)', () async {
      await repo.getSuggestions('chat-1');
      now = now.add(MeetupRepositoryImpl.suggestionsMemoryTtl);

      await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-1'], 2);
    });

    test('only the 10 most recently used chats are kept; the least recently used is dropped', () async {
      for (var i = 0; i < MeetupRepositoryImpl.suggestionsMemorySize; i++) {
        await repo.getSuggestions('chat-$i');
      }
      await repo.getSuggestions('chat-0'); // chat-0 is used again, so chat-1 is now the oldest
      await repo.getSuggestions('chat-new'); // one too many: chat-1 is evicted

      await repo.getSuggestions('chat-0');
      await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-0'], 1, reason: 'recently used, still in memory');
      expect(remote.callsPerChat['chat-1'], 2, reason: 'least recently used, evicted');
    });

    test('an hour that ended while it was in memory is not offered', () async {
      // The first hour ends at 10:01; the answer is read again from memory at 10:01:30.
      remote.starts = [_now.subtract(const Duration(minutes: 59)), _now.add(const Duration(hours: 3))];
      await repo.getSuggestions('chat-1');
      now = now.add(const Duration(minutes: 1, seconds: 30));

      final remembered = await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-1'], 1);
      expect(remembered.slots.map((s) => s.startsAt), [_now.add(const Duration(hours: 3))]);
    });

    test('proposing a meeting in a chat forgets its remembered hours', () async {
      await repo.getSuggestions('chat-1');

      await expectLater(
        repo.propose(chatRoomId: 'chat-1', meetingPointId: 'z1', startsAt: _now, endsAt: _now),
        throwsA(isA<DataException>()),
      );
      await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-1'], 2);
    });

    test('another account on the same phone does not get my remembered hours', () async {
      final owner = SessionOwner()..signedIn('ana');
      repo = MeetupRepositoryImpl(remote, owner: owner, now: () => now);
      await repo.getSuggestions('chat-1');

      owner.signedIn('luis');
      await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-1'], 2);
    });

    test('a failed request is not remembered', () async {
      remote.error = const NetworkException('offline');
      await expectLater(repo.getSuggestions('chat-1'), throwsA(isA<DataException>()));

      remote.error = null;
      await repo.getSuggestions('chat-1');

      expect(remote.callsPerChat['chat-1'], 2);
    });
  });

  // ─── S2 · Ranking in a background isolate ───────────────────────────────────

  group('Meeting point ranking in an isolate', () {
    final recommend = RecommendMeetingPointUseCase(const RankMeetingPointsUseCase());
    final zones = [
      _zone('far-monitored', monitored: true, lat: 4.6050),
      _zone('near', monitored: false, lat: 4.6020),
      _zone('mid', monitored: true, lat: 4.6030),
    ];
    const here = GeoPoint(4.6020, -74.065);
    const density = MeetingPointDensity({
      'mid': {12: 4},
      'near': {12: 1},
    });

    test('the background ranking is the same as the one on the UI thread', () async {
      final at = DateTime(2026, 11, 27, 12);
      final onUiThread = recommend.execute(zones: zones, from: here, meetingAt: at, density: density).ranked;
      final inIsolate =
          (await recommend.executeInBackground(zones: zones, from: here, meetingAt: at, density: density)).ranked;

      expect(inIsolate.map((r) => r.zone.id), onUiThread.map((r) => r.zone.id));
      expect(inIsolate.map((r) => r.score), onUiThread.map((r) => r.score));
      expect(inIsolate.map((r) => r.walkMinutes), onUiThread.map((r) => r.walkMinutes));
      expect(inIsolate.first.bestMatch, isTrue);
      expect(inIsolate.skip(1).any((r) => r.bestMatch), isFalse);
    });

    test('the hour changes the result: at night an unmonitored zone loses its place', () async {
      final noon = await recommend.executeInBackground(zones: zones, from: here, meetingAt: DateTime(2026, 11, 27, 12));
      final night = await recommend.executeInBackground(zones: zones, from: here, meetingAt: DateTime(2026, 11, 27, 21));

      expect(noon.best?.zone.id, 'near');
      expect(night.best?.zone.id, isNot('near'));
    });

    test('no zones answers an empty ranking', () async {
      final result = await recommend.executeInBackground(zones: const [], meetingAt: _now);

      expect(result.ranked, isEmpty);
      expect(result.best, isNull);
    });
  });

  // ─── I1 · Cached map tiles ──────────────────────────────────────────────────

  group('CachedTileProvider', () {
    test('tiles are loaded through cached_network_image with their own disk cache', () {
      final disk = _FakeCacheManager();
      final provider = CachedTileProvider(
        headers: {'User-Agent': 'flutter_map (com.example.flutter_front_end)'},
        cacheManager: disk,
      );
      final layer = TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

      final image = provider.getImage(const TileCoordinates(4823, 7929, 14), layer);

      expect(image, isA<CachedNetworkImageProvider>());
      final cached = image as CachedNetworkImageProvider;
      expect(cached.url, 'https://tile.openstreetmap.org/14/4823/7929.png');
      expect(cached.headers?['User-Agent'], contains('com.example.flutter_front_end'));
      expect(cached.cacheManager, same(disk));
    });

    test('map tiles are kept apart from listing photos, for 30 days', () {
      expect(MapTileCacheManager.key, isNot('campusSwapListingImages'));
      expect(MapTileCacheManager.stalePeriod, const Duration(days: 30));
    });
  });
}
