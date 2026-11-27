import '../../../app/network/api_client.dart';
import '../../entities/meetup_entities.dart';
import '../meetup_repositories.dart';
import '../../data_sources/device_location_data_source.dart';
import '../../data_sources/local/campus_zones_asset_data_source.dart';
import '../../data_sources/local/expiring_lru_cache.dart';
import '../../data_sources/local/response_cache.dart';
import '../../data_sources/meetup_remote_data_source.dart';
import '../../dto/marketplace_models.dart';
import '../../rules/free_slot_expiry.dart';
import '../../services/session_owner.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// EC9: meeting points and shared free hours keep working offline.
///
/// - Meeting points: network, falling back to the copy in `cached_responses`, and then to the
///   zones bundled in `assets/campus_zones.json`.
/// - Free hours: network, falling back to the copy in `cached_responses`, without the hours that
///   already ended.
///
/// Without a [cache] it is network only (plus the bundled zones, when given).
///
/// In front of all that, the free hours of the last [suggestionsMemorySize] chats are kept in an
/// in-memory LRU cache for [suggestionsMemoryTtl]: reopening the planner for the same chat shows
/// them at once, without a request. The least recently used chat is dropped when a new one does
/// not fit, and an entry older than the TTL is asked for again (schedules can change).
class MeetupRepositoryImpl implements MeetupRepository {
  static const int suggestionsMemorySize = 10;
  static const Duration suggestionsMemoryTtl = Duration(minutes: 2);

  /// Campus zones are the same for everybody, so one copy serves every account.
  static const String meetingPointsOwner = 'global';
  static const String meetingPointsKey = 'meeting_points';
  static String suggestionsKey(String chatRoomId) => 'meeting_suggestions:$chatRoomId';

  final MeetupRemoteDataSource remote;
  final ResponseCache? cache;
  final SessionOwner? owner;
  final CampusZonesAssetDataSource? bundledZones;
  final DateTime Function() _now;

  /// Free hours per chat (key: user and chat), most recently used last.
  final ExpiringLruCache<String, MeetingSuggestions> _suggestionsMemory;

  MeetupRepositoryImpl(
    this.remote, {
    this.cache,
    this.owner,
    this.bundledZones,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _suggestionsMemory = ExpiringLruCache(
          maxSize: suggestionsMemorySize,
          ttl: suggestionsMemoryTtl,
          now: now ?? DateTime.now,
        );

  String _memoryKey(String chatRoomId) => '${owner?.userId ?? ''}:$chatRoomId';

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() => guardRequest(() async {
        try {
          final cache = this.cache;
          if (cache == null) return await remote.getMeetingPoints();
          final result = await cache.networkFirst(
            ownerId: meetingPointsOwner,
            key: meetingPointsKey,
            fetch: remote.getMeetingPointsJson,
            parse: (json) => parseList(json, meetingPointFromJson),
          );
          return result.data;
        } on Exception catch (e) {
          // Server unreachable and nothing saved yet: the zones shipped with the app.
          if (!_isUnreachable(e)) rethrow;
          final bundled = await bundledZones?.getMeetingPoints() ?? const <MeetingPointEntity>[];
          if (bundled.isEmpty) rethrow;
          return bundled;
        }
      });

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async {
    final memoryKey = _memoryKey(chatRoomId);
    final remembered = _suggestionsMemory.get(memoryKey);
    // Up to two minutes old: an hour that ended meanwhile is dropped (the planner also hides
    // the ones that already started).
    if (remembered != null) return FreeSlotExpiry.dropEnded(remembered, _now());

    final fresh = await _loadSuggestions(chatRoomId);
    if (fresh.fromServer) _suggestionsMemory.put(memoryKey, fresh.suggestions);
    return fresh.suggestions;
  }

  /// Network first, then the saved copy. Only an answer straight from the server is worth
  /// remembering in memory; an offline copy is read again next time, in case the network is back.
  Future<({MeetingSuggestions suggestions, bool fromServer})> _loadSuggestions(String chatRoomId) {
    final cache = this.cache;
    final userId = owner?.userId;
    if (cache == null || userId == null) {
      return guardRequest(() async => (suggestions: await remote.getSuggestions(chatRoomId), fromServer: true));
    }
    return guardRequest(() async {
      final result = await cache.networkFirst(
        ownerId: userId,
        key: suggestionsKey(chatRoomId),
        fetch: () => remote.getSuggestionsJson(chatRoomId),
        parse: (json) => meetingSuggestionsFromJson(json as Json),
      );
      // A fresh answer only has upcoming hours; a saved copy may be old.
      return result.fromCache
          ? (suggestions: FreeSlotExpiry.dropEnded(result.data, _now()), fromServer: false)
          : (suggestions: result.data, fromServer: true);
    });
  }

  /// Same rule as [ResponseCache.networkFirst]: no network, or the server failing (5xx).
  static bool _isUnreachable(Exception e) =>
      e is NetworkException || (e is ApiException && e.statusCode >= 500);

  @override
  Future<MeetingProposalEntity> propose({
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    // The chat's plans changed: the next planner opening asks the server again.
    _suggestionsMemory.remove(_memoryKey(chatRoomId));
    return guardRequest(() => remote.createProposal(meetingProposalToJson(
          chatRoomId: chatRoomId,
          meetingPointId: meetingPointId,
          startsAt: startsAt,
          endsAt: endsAt,
        )));
  }

  @override
  Future<MeetingProposalEntity> accept(String proposalId) =>
      guardRequest(() => remote.answerProposal(proposalId, 'accept'));

  @override
  Future<MeetingProposalEntity> decline(String proposalId) =>
      guardRequest(() => remote.answerProposal(proposalId, 'decline'));

  @override
  Future<MeetingProposalEntity> withdraw(String proposalId) =>
      guardRequest(() => remote.answerProposal(proposalId, 'cancel'));
}

class ScheduleRepositoryImpl implements ScheduleRepository {
  final MeetupRemoteDataSource remote;

  ScheduleRepositoryImpl(this.remote);

  @override
  Future<List<ScheduleBlockEntity>> getSchedule() => guardRequest(remote.getSchedule);

  @override
  Future<ScheduleBlockEntity> add(NewScheduleBlock block) => guardRequest(() => remote.addScheduleBlock({
        'dayOfWeek': block.dayOfWeek,
        'startMinute': block.startMinute,
        'endMinute': block.endMinute,
        'label': ?block.label,
      }));

  @override
  Future<void> remove(String blockId) => guardRequest(() => remote.removeScheduleBlock(blockId));
}

class LocationRepositoryImpl implements LocationRepository {
  final DeviceLocationDataSource device;

  LocationRepositoryImpl(this.device);

  @override
  Future<GeoPoint?> currentLocation() async {
    try {
      return await device.currentLocation();
    } on Exception {
      // Walking times are a nice-to-have: without a location the zones are still listed.
      return null;
    }
  }
}
