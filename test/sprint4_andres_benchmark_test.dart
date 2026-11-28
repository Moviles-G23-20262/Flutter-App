// Sprint 4 · micro-optimization measurements (Andrés Botero): MO7, MO8 and MO9.
//
// Every measurement only uses APIs that existed before the optimizations, so the same file runs
// on the code before and after them and prints comparable numbers. Run it with:
//
//   flutter test test/sprint4_andres_benchmark_test.dart --reporter expanded
//
// Each test prints one `[MO…]` line with the figure that goes in the wiki.

import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/exchange_entity.dart';
import 'package:flutter_front_end/model/entities/meeting_point_density.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/entities/notification_entity.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/view_model/account_view_model.dart';
import 'package:flutter_front_end/view_model/meeting_planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─── MO7 fixture: a chat thread as the server returns it ─────────────────────

List<Map<String, Object?>> _thread(int messages) => [
      for (var i = 0; i < messages; i++)
        {
          'id': 'msg-$i',
          'chatRoomId': 'room-1',
          'senderId': i.isEven ? 'ana' : 'luis',
          'content': 'Message number $i about the calculus book and where to meet',
          'isRead': true,
          'createdAt': DateTime.utc(2026, 11, 27, 10, i % 60).toIso8601String(),
        },
    ];

// ─── MO8 fixtures: the meeting planner with counted rankings ────────────────

/// Counts how many background rankings (isolates) the planner starts.
class _CountingRecommend extends RecommendMeetingPointUseCase {
  int isolatesStarted = 0;

  _CountingRecommend() : super(const RankMeetingPointsUseCase());

  @override
  Future<MeetingPointRecommendation> executeInBackground({
    required List<MeetingPointEntity> zones,
    GeoPoint? from,
    DateTime? meetingAt,
    DateTime? now,
    MeetingPointDensity density = MeetingPointDensity.empty,
  }) {
    isolatesStarted++;
    return super.executeInBackground(zones: zones, from: from, meetingAt: meetingAt, now: now, density: density);
  }
}

class _Meetups implements MeetupRepository {
  final List<MeetingPointEntity> zones;
  final MeetingSuggestions suggestions;

  _Meetups(this.zones, this.suggestions);

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async => zones;

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async => suggestions;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FixedLocation implements LocationRepository {
  @override
  Future<GeoPoint?> currentLocation() async => const GeoPoint(4.6020, -74.0650);
}

class _NoDensity implements MeetingDensityRepository {
  @override
  Future<MeetingPointDensity> getDensity() async => MeetingPointDensity.empty;
}

// ─── MO9 fixtures: a student with many orders ────────────────────────────────

class _Orders implements ExchangeRepository {
  final List<ExchangeEntity> exchanges;
  _Orders(this.exchanges);

  @override
  Future<List<ExchangeEntity>> getExchanges() async => exchanges;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _NoNotifications implements NotificationRepository {
  @override
  Future<CachedList<NotificationEntity>> getNotifications() async => const CachedList([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

List<ExchangeEntity> _orders(int count) => [
      for (var i = 0; i < count; i++)
        ExchangeEntity(
          id: 'ex-$i',
          orderNumber: 1000 + i,
          materialId: 'm-${i % 40}',
          buyerId: i.isEven ? 'ana' : 'buyer-$i',
          sellerId: i.isEven ? 'seller-$i' : 'ana',
          price: 10000.0 + i,
          status: i % 3 == 0 ? ExchangeStatusEnum.COMPLETED : ExchangeStatusEnum.PENDING,
          createdAt: DateTime(2026, 9, 1).add(Duration(hours: i)),
          completedAt: i % 3 == 0 ? DateTime(2026, 11, 1).add(Duration(hours: i)) : null,
        ),
    ];

void main() {
  sqfliteFfiInit();

  test('MO7 · SQLite writes while a chat stays open for 60 s (15 polls, no new message)', () async {
    final db = AppDatabase.withFactory(databaseFactoryFfi);
    final cache = ResponseCache(db);
    final thread = _thread(80);
    final sqlite = await db.database;
    final before = (await sqlite.rawQuery('SELECT total_changes() AS c')).first['c'] as int;

    final watch = Stopwatch()..start();
    for (var poll = 0; poll < 15; poll++) {
      // Same answer every 4 s: each poll decodes a fresh copy, like the real client does.
      await cache.save('ana', 'messages:room-1', [for (final m in thread) Map.of(m)]);
    }
    watch.stop();

    final writes = (await sqlite.rawQuery('SELECT total_changes() AS c')).first['c'] as int;
    // ignore: avoid_print
    print('[MO7] SQLite rows written: ${writes - before} · time in save(): ${watch.elapsedMilliseconds} ms');
    expect(writes - before, greaterThan(0));
    await db.close();
  });

  test('MO8 · background rankings started while using the meeting planner', () async {
    final day = DateTime.now().add(const Duration(days: 1));
    final tenAm = DateTime(day.year, day.month, day.day, 10);
    FreeSlot slot(DateTime start) => FreeSlot(startsAt: start, endsAt: start.add(const Duration(minutes: 30)), sharedBreak: true);
    final early = slot(tenAm);
    final laterSameHour = slot(tenAm.add(const Duration(minutes: 30)));
    final afternoon = slot(tenAm.add(const Duration(hours: 5)));
    final zones = [
      for (var i = 0; i < 8; i++)
        MeetingPointEntity(
          id: 'z$i',
          name: 'Zone $i',
          zoneType: MeetingZoneTypeEnum.values.first,
          isMonitored: i.isEven,
          location: GeoPoint(4.6010 + i * 0.0005, -74.0650),
        ),
    ];
    final recommend = _CountingRecommend();
    final repo = _Meetups(
      zones,
      MeetingSuggestions(slots: [early, laterSameHour, afternoon], suggested: early, callerHasSchedule: true, otherHasSchedule: true),
    );
    final planner = MeetingPlannerViewModel(
      chatRoomId: 'room-1',
      useCases: MeetupUseCases(
        getMeetingPoints: GetMeetingPointsUseCase(repo),
        getSuggestions: GetMeetingSuggestionsUseCase(repo),
        propose: ProposeMeetingUseCase(repo),
        answer: AnswerMeetingProposalUseCase(repo),
        currentLocation: GetCurrentLocationUseCase(_FixedLocation()),
        rankZones: RankSafeZonesUseCase(),
        recommend: recommend,
        getDensity: GetMeetingPointDensityUseCase(_NoDensity()),
      ),
    );

    await planner.load();
    // The student taps around: the same hour 6 times, another slot of that hour 3 times,
    // then the afternoon once.
    for (var i = 0; i < 6; i++) {
      planner.selectSlot(early);
    }
    for (var i = 0; i < 3; i++) {
      planner.selectSlot(laterSameHour);
    }
    planner.selectSlot(afternoon);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // ignore: avoid_print
    print('[MO8] background rankings (isolates) started: ${recommend.isolatesStarted} '
        '(after load + 10 taps, only 1 of them to a different hour)');
    expect(planner.zones, isNotEmpty);
    planner.dispose();
  });

  test('MO9 · sorting orders across 1000 rebuilds (Profile, chat header, Seller Hub)', () async {
    final orders = _Orders(_orders(600));
    final notifications = _NoNotifications();
    final account = AccountViewModel(
      getExchanges: GetExchangesUseCase(orders),
      getNotifications: GetNotificationsUseCase(notifications),
      markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
      placeOrder: PlaceOrderUseCase(orders),
      completeExchange: CompleteExchangeUseCase(orders),
      cancelExchange: CancelExchangeUseCase(orders),
      rateUser: RateUserUseCase(orders),
    );
    await account.load();
    final now = DateTime(2026, 11, 27);

    // Warm-up, so the JIT does not count against the first variant measured.
    for (var i = 0; i < 50; i++) {
      account.purchasesOf('ana');
    }

    final watch = Stopwatch()..start();
    for (var build = 0; build < 1000; build++) {
      account.purchasesOf('ana'); // Profile
      account.latestOrderFor('m-${build % 40}', 'ana'); // chat header, every 4 s poll
      account.salesOf('ana'); // Seller Hub recent sales
      account.earnedThisMonth('ana', now: now); // Seller Hub stat card
    }
    watch.stop();

    // ignore: avoid_print
    print('[MO9] 1000 rebuilds over 600 orders: ${watch.elapsedMilliseconds} ms');
    expect(account.purchasesOf('ana'), isNotEmpty);
  });
}
