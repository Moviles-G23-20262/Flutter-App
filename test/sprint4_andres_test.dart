import 'package:flutter/foundation.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/dto/course_demand_model.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/course_demand.dart';
import 'package:flutter_front_end/model/entities/exchange_entity.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/entities/notification_entity.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/course_demand_repository.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/rules/my_meetups.dart';
import 'package:flutter_front_end/model/use_cases/get_course_demand_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/view_model/account_view_model.dart';
import 'package:flutter_front_end/view_model/course_demand_view_model.dart';
import 'package:flutter_front_end/view_model/my_meetups_view_model.dart';
import 'package:flutter_front_end/model/entities/meeting_point_density.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/view_model/meeting_planner_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _now = DateTime(2026, 11, 27, 10);

ExchangeEntity _order(
  String id, {
  String buyer = 'ana',
  String seller = 'luis',
  ExchangeStatusEnum status = ExchangeStatusEnum.PENDING,
  DateTime? startsAt,
  DateTime? createdAt,
  DateTime? completedAt,
}) =>
    ExchangeEntity(
      id: id,
      orderNumber: 1000,
      materialId: 'm-$id',
      buyerId: buyer,
      sellerId: seller,
      price: 20000,
      status: status,
      createdAt: createdAt ?? DateTime(2026, 11, 1),
      completedAt: completedAt,
      meetingStartsAt: startsAt,
      meetingEndsAt: startsAt?.add(const Duration(hours: 1)),
      buyer: UserSummary(id: buyer, fullName: 'Buyer $buyer', major: 'ISIS', rating: 4),
      seller: UserSummary(id: seller, fullName: 'Seller $seller', major: 'ISIS', rating: 4),
    );

class _Orders implements ExchangeRepository {
  List<ExchangeEntity> exchanges;
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

AccountViewModel _account(_Orders orders) {
  final notifications = _NoNotifications();
  return AccountViewModel(
    getExchanges: GetExchangesUseCase(orders),
    getNotifications: GetNotificationsUseCase(notifications),
    markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
    placeOrder: PlaceOrderUseCase(orders),
    completeExchange: CompleteExchangeUseCase(orders),
    cancelExchange: CancelExchangeUseCase(orders),
    rateUser: RateUserUseCase(orders),
  );
}

class _CourseDemand implements CourseDemandRepository {
  Object? json;
  DateTime? savedAt;
  Exception? error;
  int calls = 0;

  @override
  Future<({CourseDemandReport report, DateTime? savedAt})> getCourseDemand() async {
    calls++;
    if (error != null) throw error!;
    return (report: courseDemandFromJson(json), savedAt: savedAt);
  }
}

Map<String, Object?> _courseJson(String course, {int available = 0, int interested = 3, String status = 'shortage'}) => {
      'course': course,
      'listings': available + 1,
      'available': available,
      'sold': 1,
      'buyers_in_chat': interested,
      'wishlist_saves': 0,
      'interested_students': interested,
      'demand_per_listing': available == 0 ? null : interested / available,
      'gap': interested - available,
      'status': status,
    };

class _Meetups implements MeetupRepository {
  final MeetingSuggestions suggestions;
  _Meetups(this.suggestions);

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async => [
        for (var i = 0; i < 4; i++)
          MeetingPointEntity(
            id: 'z$i',
            name: 'Zone $i',
            zoneType: MeetingZoneTypeEnum.values.first,
            isMonitored: i.isEven,
            location: GeoPoint(4.601 + i * 0.001, -74.065),
          ),
      ];

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async => suggestions;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Here implements LocationRepository {
  @override
  Future<GeoPoint?> currentLocation() async => const GeoPoint(4.602, -74.065);
}

class _NoDensity implements MeetingDensityRepository {
  @override
  Future<MeetingPointDensity> getDensity() async => MeetingPointDensity.empty;
}

void main() {
  sqfliteFfiInit();

  // ─── MO8 · The planner re-ranks only when the result can change ──────────────

  test('MO8 the same hour, another slot of that hour, or the same GPS spot do not start an isolate', () async {
    final day = DateTime.now().add(const Duration(days: 1));
    final ten = DateTime(day.year, day.month, day.day, 10);
    FreeSlot slot(DateTime start) => FreeSlot(startsAt: start, endsAt: start.add(const Duration(minutes: 30)), sharedBreak: true);
    final early = slot(ten), sameHour = slot(ten.add(const Duration(minutes: 30))), afternoon = slot(ten.add(const Duration(hours: 5)));
    final repo = _Meetups(MeetingSuggestions(slots: [early, sameHour, afternoon], suggested: early, callerHasSchedule: true, otherHasSchedule: true));
    final planner = MeetingPlannerViewModel(
      chatRoomId: 'r1',
      useCases: MeetupUseCases(
        getMeetingPoints: GetMeetingPointsUseCase(repo),
        getSuggestions: GetMeetingSuggestionsUseCase(repo),
        propose: ProposeMeetingUseCase(repo),
        answer: AnswerMeetingProposalUseCase(repo),
        currentLocation: GetCurrentLocationUseCase(_Here()),
        rankZones: RankSafeZonesUseCase(),
        recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
        getDensity: GetMeetingPointDensityUseCase(_NoDensity()),
      ),
    );
    await planner.load();
    await planner.rankingDone;
    final startedAfterLoad = planner.rankingsStarted;

    planner.selectSlot(early);
    planner.selectSlot(sameHour);
    await planner.rankingDone;
    expect(planner.rankingsStarted, startedAfterLoad, reason: 'same hour: same ranking');

    planner.selectSlot(afternoon);
    await planner.rankingDone;
    expect(planner.rankingsStarted, startedAfterLoad + 1, reason: 'another hour changes the ranking');
    expect(planner.rankingsSkipped, greaterThanOrEqualTo(2));
    expect(planner.zones, hasLength(4));
    planner.dispose();
  });

  // ─── MO7 · Saved answers are not rewritten when nothing changed ──────────────

  group('MO7 ResponseCache skips identical writes', () {
    late AppDatabase db;
    late DateTime now;
    late ResponseCache cache;

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      now = _now;
      cache = ResponseCache(db, now: () => now);
    });
    tearDown(() => db.close());

    test('the same answer 15 times is written to SQLite once', () async {
      for (var i = 0; i < 15; i++) {
        await cache.save('ana', 'messages:r1', [
          {'id': 'm1', 'content': 'hi'},
        ]);
        now = now.add(const Duration(seconds: 4));
      }

      expect(cache.diskWrites, 1);
      expect(cache.skippedWrites, 14);
    });

    test('a changed answer is written at once', () async {
      await cache.save('ana', 'messages:r1', ['hi']);
      await cache.save('ana', 'messages:r1', ['hi', 'are you there?']);

      expect(cache.diskWrites, 2);
      expect((await ResponseCache(db).read('ana', 'messages:r1'))!.data, ['hi', 'are you there?']);
    });

    test('the same answer is written again after 5 minutes, so the saved age stays right', () async {
      await cache.save('ana', 'inbox', ['r1']);
      now = now.add(ResponseCache.refreshSavedAtEvery);
      await cache.save('ana', 'inbox', ['r1']);

      expect(cache.diskWrites, 2);
      expect((await ResponseCache(db).read('ana', 'inbox'))!.savedAt, now);
    });

    test('the memory copy is refreshed even when the disk write is skipped', () async {
      await cache.save('ana', 'inbox', ['r1']);
      now = now.add(const Duration(seconds: 30));
      await cache.save('ana', 'inbox', ['r1']);

      expect((await cache.read('ana', 'inbox'))!.savedAt, now);
    });

    test('each user and key is tracked on its own, and removing a copy forgets it', () async {
      await cache.save('ana', 'inbox', ['r1']);
      await cache.save('luis', 'inbox', ['r1']);
      await cache.remove('ana', 'inbox');
      await cache.save('ana', 'inbox', ['r1']);

      expect(cache.diskWrites, 3);
      expect((await ResponseCache(db).read('ana', 'inbox'))!.data, ['r1']);
    });
  });

  // ─── MO9 · Order lists sorted once per version ───────────────────────────────

  group('MO9 AccountViewModel sorts each order list once', () {
    test('repeated rebuilds reuse the sorted lists', () async {
      final account = _account(_Orders([_order('1'), _order('2', buyer: 'sofi', seller: 'ana')]));
      await account.load();

      for (var i = 0; i < 100; i++) {
        account.purchasesOf('ana');
        account.salesOf('ana');
        account.latestOrderFor('m-1', 'ana');
      }

      expect(account.sortComputations, 3);
    });

    test('new orders from the server are sorted again', () async {
      final orders = _Orders([_order('1')]);
      final account = _account(orders);
      await account.load();
      expect(account.purchasesOf('ana').map((e) => e.id), ['1']);

      orders.exchanges = [_order('1'), _order('2', createdAt: DateTime(2026, 11, 20))];
      await account.refreshExchanges();

      expect(account.purchasesOf('ana').map((e) => e.id), ['2', '1']);
      expect(account.sortComputations, 2);
    });

    test('the cached lists cannot be changed by a screen', () async {
      final account = _account(_Orders([_order('1')]));
      await account.load();

      expect(() => account.purchasesOf('ana').add(_order('x')), throwsUnsupportedError);
    });
  });

  // ─── New view · My meetups ────────────────────────────────────────────────────

  group('MyMeetups grouping', () {
    test('upcoming, to confirm and not agreed, each in its own order', () {
      final meetups = MyMeetups.from(
        [
          _order('later', startsAt: _now.add(const Duration(days: 2))),
          _order('soon', startsAt: _now.add(const Duration(hours: 1))),
          _order('now', startsAt: _now.subtract(const Duration(minutes: 30))), // ends at 10:30
          _order('passed', startsAt: _now.subtract(const Duration(days: 1))),
          _order('no-time-old', createdAt: DateTime(2026, 11, 1)),
          _order('no-time-new', createdAt: DateTime(2026, 11, 20)),
        ],
        userId: 'ana',
        now: _now,
      );

      expect(meetups.upcoming.map((m) => m.exchange.id), ['now', 'soon', 'later']);
      expect(meetups.toComplete.map((m) => m.exchange.id), ['passed']);
      expect(meetups.notAgreed.map((m) => m.exchange.id), ['no-time-new', 'no-time-old']);
      expect(meetups.next?.exchange.id, 'now');
    });

    test('completed, cancelled and other people\'s orders are not meetups', () {
      final meetups = MyMeetups.from(
        [
          _order('done', status: ExchangeStatusEnum.COMPLETED, startsAt: _now.add(const Duration(hours: 1))),
          _order('cancelled', status: ExchangeStatusEnum.CANCELLED, startsAt: _now.add(const Duration(hours: 1))),
          _order('others', buyer: 'sofi', seller: 'luis', startsAt: _now.add(const Duration(hours: 1))),
        ],
        userId: 'ana',
        now: _now,
      );

      expect(meetups.isEmpty, isTrue);
    });

    test('the other student is the seller when buying and the buyer when selling', () {
      final meetups = MyMeetups.from(
        [
          _order('buying', startsAt: _now.add(const Duration(hours: 1))),
          _order('selling', buyer: 'sofi', seller: 'ana', startsAt: _now.add(const Duration(hours: 2))),
        ],
        userId: 'ana',
        now: _now,
      );

      expect(meetups.upcoming.first.isBuyer, isTrue);
      expect(meetups.upcoming.first.other?.id, 'luis');
      expect(meetups.upcoming.last.isBuyer, isFalse);
      expect(meetups.upcoming.last.other?.id, 'sofi');
    });
  });

  group('MyMeetupsViewModel', () {
    test('follows the orders and groups them once per change', () async {
      final changes = ChangeNotifier();
      var exchanges = [_order('soon', startsAt: _now.add(const Duration(hours: 1)))];
      var refreshed = 0;
      var notified = 0;
      final vm = MyMeetupsViewModel(
        userId: 'ana',
        exchanges: () => exchanges,
        changes: changes,
        refresh: () async => refreshed++,
        isLoading: () => false,
        now: () => _now,
      )..addListener(() => notified++);

      final first = vm.meetups;
      expect(identical(vm.meetups, first), isTrue, reason: 'same orders, same grouping');
      expect(first.upcoming, hasLength(1));

      exchanges = [...exchanges, _order('passed', startsAt: _now.subtract(const Duration(days: 1)))];
      changes.notifyListeners();
      expect(notified, 1);
      expect(vm.meetups.toComplete, hasLength(1));

      await vm.refresh();
      expect(refreshed, 1);

      vm.dispose();
      changes.notifyListeners();
      expect(notified, 1, reason: 'stops listening once disposed');
    });
  });

  // ─── BQ 19 · Most wanted courses card ─────────────────────────────────────────

  group('BQ19 course demand', () {
    test('the answer of the analytics service is read into the report', () {
      final report = courseDemandFromJson({
        'total_courses': 3,
        'shortage_courses': 2,
        'courses': [
          _courseJson('MATE1203'),
          _courseJson('DISE1101', available: 1, interested: 2),
          _courseJson('FISI1018', available: 2, interested: 1, status: 'balanced'),
        ],
      });

      expect(report.totalCourses, 3);
      expect(report.mostWanted.map((c) => c.course), ['MATE1203', 'DISE1101']);
      expect(report.courses.first.demandPerListing, isNull);
      expect(report.courses[1].demandPerListing, 2.0);
    });

    test('the card shows at most 5 courses short of listings, and the saved copy is flagged', () async {
      final repo = _CourseDemand()
        ..json = {
          'total_courses': 7,
          'shortage_courses': 7,
          'courses': [for (var i = 0; i < 7; i++) _courseJson('C$i')],
        }
        ..savedAt = _now;
      final vm = CourseDemandViewModel(getCourseDemand: GetCourseDemandUseCase(repo));

      await vm.load();
      await vm.load(); // already loaded: no second request

      expect(repo.calls, 1);
      expect(vm.mostWanted.map((c) => c.course), ['C0', 'C1', 'C2', 'C3', 'C4']);
      expect(vm.isSavedCopy, isTrue);
      vm.dispose();
    });

    test('without a connection and nothing saved, the card explains it', () async {
      final repo = _CourseDemand()..error = const NoConnectionException();
      final vm = CourseDemandViewModel(getCourseDemand: GetCourseDemandUseCase(repo));

      await vm.load();

      expect(vm.report, isNull);
      expect(vm.error, contains("Can't reach the server"));
      vm.dispose();
    });
  });
}
