// Sprint 4 micro-optimizations:
// MO1 analytics queue counted in memory + timer paused in the background,
// MO2 chat polling paused in the background,
// MO3 copPrice's RegExp compiled once and the Seller Hub sublists memoized.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/analytics_event_remote_data_source.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/chat_room_entity.dart';
import 'package:flutter_front_end/model/entities/enums.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/conversation_insight_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/analytics_event_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/services/analytics_sync_service.dart';
import 'package:flutter_front_end/model/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/view/screens/seller_hub_screen.dart';
import 'package:flutter_front_end/view/widgets/formatters.dart';
import 'package:flutter_front_end/view_model/account_view_model.dart';
import 'package:flutter_front_end/view_model/chat_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Network implements ConnectivityRepository {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => const Stream.empty();
}

/// Waits (for real) until [condition] holds, so fire-and-forget work can finish.
Future<void> _eventually(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

// ── Chat fakes ────────────────────────────────────────────────────────────────

class _Chats implements ChatRepository {
  int roomLoads = 0;
  int messageLoads = 0;

  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() async {
    roomLoads++;
    return const CachedList([]);
  }

  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) async {
    messageLoads++;
    return const CachedList([]);
  }

  @override
  Future<void> markRead(String chatRoomId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoMeetups implements MeetupRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoInsights implements ConversationInsightRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoTracker implements AnalyticsEventRepository {
  @override
  Future<void> track(AnalyticsEvent event) async {}
}

ChatViewModel _chatViewModel(_Chats chats) => ChatViewModel(
      getChatRooms: GetChatRoomsUseCase(chats),
      openChatRoom: OpenChatRoomUseCase(chats),
      getMessages: GetMessagesUseCase(chats),
      sendMessage: SendMessageUseCase(chats),
      markRead: MarkChatReadUseCase(chats),
      answerProposal: AnswerMeetingProposalUseCase(_NoMeetups()),
      getConversationInsight: GetConversationInsightUseCase(_NoInsights()),
      getChatAgreement: GetChatAgreementUseCase(_NoInsights()),
      trackEvent: TrackEventUseCase(_NoTracker()),
    );

// ── Seller Hub fakes ──────────────────────────────────────────────────────────

class _NoExchanges implements ExchangeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoNotifications implements NotificationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

MaterialEntity _material(String id, String sellerId, {MaterialStatusEnum status = MaterialStatusEnum.AVAILABLE}) =>
    MaterialEntity(
      id: id,
      title: 'Item $id',
      description: 'A used item',
      price: 10000,
      status: status,
      imageUrls: const [],
      sellerId: sellerId,
      category: MaterialCategoryEnum.BOOKS,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  group('MO1 · AnalyticsSyncService keeps the queue size in memory', () {
    late Directory dir;
    late _Network network;
    late int directoryCalls;
    late List<int> batchSizes;
    late List<int> statuses;

    AnalyticsSyncService service() {
      AnalyticsSyncService.reset();
      return AnalyticsSyncService(
        remote: AnalyticsEventRemoteDataSource(
          apiClient: ApiClient(
            baseUrl: 'https://api.test',
            client: MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              batchSizes.add((body['events'] as List).length);
              return http.Response('{}', statuses.isEmpty ? 201 : statuses.removeAt(0));
            }),
          ),
        ),
        connectivity: network,
        directory: () async {
          directoryCalls++;
          return dir;
        },
      );
    }

    Future<void> queue(AnalyticsEventRepositoryImpl repository, int count) async {
      final track = TrackEventUseCase(repository);
      for (var i = 0; i < count; i++) {
        await track.execute(AnalyticsEventType.LISTING_VIEW, materialId: 'm$i');
      }
    }

    int lines() {
      final file = File('${dir.path}/${AnalyticsEventRepositoryImpl.fileName}');
      return file.existsSync() ? file.readAsLinesSync().length : 0;
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('mo1');
      network = _Network();
      directoryCalls = 0;
      batchSizes = [];
      statuses = [];
    });

    tearDown(() {
      AnalyticsSyncService.reset();
      dir.deleteSync(recursive: true);
    });

    test('init() reads the queue files once and counts their events', () async {
      await queue(AnalyticsEventRepositoryImpl(directory: () async => dir), 3);
      final sync = service();

      await sync.init();
      await sync.init();

      expect(sync.pendingCount, 3);
      expect(directoryCalls, 1);
    });

    test('every tracked event adds one to the count (+1 on enqueue)', () async {
      final sync = service();
      await sync.init();
      final repository = AnalyticsEventRepositoryImpl(directory: () async => dir, onQueued: sync.recordQueued);

      await queue(repository, 4);

      expect(sync.pendingCount, 4);
    });

    test('a timer tick with nothing queued returns at once: no disk, no request', () async {
      final sync = service();

      await sync.onTick();
      await sync.onTick();

      expect(sync.pendingCount, 0);
      expect(directoryCalls, 0);
      expect(batchSizes, isEmpty);
    });

    test('a tick with events uploads them and the count goes back to 0', () async {
      final sync = service();
      final repository = AnalyticsEventRepositoryImpl(directory: () async => dir, onQueued: sync.recordQueued);
      await queue(repository, 12);

      await sync.onTick();

      expect(batchSizes, [10, 2]);
      expect(sync.pendingCount, 0);
      expect(lines(), 0);
    });

    test('a failed batch keeps its events counted (-sentCount only for accepted batches)', () async {
      final sync = service();
      final repository = AnalyticsEventRepositoryImpl(directory: () async => dir, onQueued: sync.recordQueued);
      await queue(repository, 25);
      statuses = [201, 500];

      await sync.onTick();

      expect(sync.pendingCount, 15);
      expect(lines(), 15);
    });

    test('the count never goes below zero', () async {
      // Events written by a repository that does not report them: the counter starts at 0.
      await queue(AnalyticsEventRepositoryImpl(directory: () async => dir), 5);
      final sync = service();

      await sync.syncNow();

      expect(batchSizes, [5]);
      expect(sync.pendingCount, 0);
    });

    test('offline, a tick with events queued keeps them and their count', () async {
      final sync = service();
      final repository = AnalyticsEventRepositoryImpl(directory: () async => dir, onQueued: sync.recordQueued);
      await queue(repository, 2);
      network.online = false;

      await sync.onTick();

      expect(batchSizes, isEmpty);
      expect(sync.pendingCount, 2);
    });

    test('pause() stops the timer and keeps the queue; resume() restarts it and flushes', () async {
      await queue(AnalyticsEventRepositoryImpl(directory: () async => dir), 3);
      network.online = false; // start() must not send yet
      final sync = service();
      sync.start();
      await sync.init();
      expect(sync.isTimerActive, isTrue);

      sync.pause();
      expect(sync.isTimerActive, isFalse);
      expect(sync.pendingCount, 3);
      expect(batchSizes, isEmpty);

      network.online = true;
      sync.resume();
      expect(sync.isTimerActive, isTrue);
      await _eventually(() => batchSizes.isNotEmpty && !sync.isSyncing);

      expect(batchSizes, [3]);
      expect(sync.pendingCount, 0);
    });

    test('resume() with an empty queue only restarts the timer', () async {
      final sync = service();
      sync.start();
      await sync.init();
      sync.pause();
      final callsBefore = directoryCalls;

      sync.resume();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(sync.isTimerActive, isTrue);
      expect(directoryCalls, callsBefore);
      expect(batchSizes, isEmpty);
    });

    test('resume() before start() or after stop() does nothing', () {
      final sync = service();

      sync.resume();
      expect(sync.isTimerActive, isFalse);

      sync.start();
      sync.stop();
      sync.resume();
      expect(sync.isTimerActive, isFalse);
    });
  });

  group('MO2 · ChatViewModel stops polling in the background', () {
    late _Chats chats;
    late ChatViewModel vm;

    setUp(() {
      chats = _Chats();
      vm = _chatViewModel(chats);
      vm.start('ana');
    });

    tearDown(() => vm.dispose());

    test('paused cancels the poll timer at once; resumed restarts it and refreshes now', () {
      vm.startPolling();
      expect(vm.isPolling, isTrue);

      vm.pauseForBackground();
      expect(vm.isPolling, isFalse);
      expect(vm.isInBackground, isTrue);

      final loadsBefore = chats.roomLoads;
      vm.resumeFromBackground();

      expect(vm.isPolling, isTrue);
      expect(chats.roomLoads, loadsBefore + 1);
    });

    test('with a conversation open, the refresh on return is of its messages', () {
      vm.openRoom('r1');
      vm.pauseForBackground();
      final before = chats.messageLoads;

      vm.resumeFromBackground();

      expect(vm.isPolling, isTrue);
      expect(chats.messageLoads, before + 1);
    });

    test('back in the foreground without a connection it does not poll', () {
      vm.startPolling();
      vm.pauseForBackground();
      vm.setOffline(true);

      vm.resumeFromBackground();
      expect(vm.isPolling, isFalse);

      vm.setOffline(false);
      expect(vm.isPolling, isTrue);
    });

    test('the network coming back while in the background waits for the app to return', () {
      vm.setOffline(true);
      vm.pauseForBackground();

      vm.setOffline(false);
      expect(vm.isPolling, isFalse);

      vm.resumeFromBackground();
      expect(vm.isPolling, isTrue);
    });

    test('a chat that was not polling stays idle on return', () {
      vm.stopPolling();
      vm.pauseForBackground();
      final before = chats.roomLoads;

      vm.resumeFromBackground();

      expect(vm.isPolling, isFalse);
      expect(chats.roomLoads, before);
    });

    test('after sign-out nothing restarts on return', () {
      vm.startPolling();
      vm.pauseForBackground();
      vm.clear();

      vm.resumeFromBackground();

      expect(vm.isPolling, isFalse);
    });
  });

  group('MO3 · copPrice and the Seller Hub sublists', () {
    test('copPrice groups thousands with dots (pattern compiled once)', () {
      expect(copPrice(999), r'$999 COP');
      expect(copPrice(320000), r'$320.000 COP');
      expect(copPrice(1234567.4), r'$1.234.567 COP');
      expect(copPrice(50000000), r'$50.000.000 COP');
    });

    AccountViewModel account() => AccountViewModel(
          getExchanges: GetExchangesUseCase(_NoExchanges()),
          getNotifications: GetNotificationsUseCase(_NoNotifications()),
          markNotificationOpened: MarkNotificationOpenedUseCase(_NoNotifications()),
          placeOrder: PlaceOrderUseCase(_NoExchanges()),
          completeExchange: CompleteExchangeUseCase(_NoExchanges()),
          cancelExchange: CancelExchangeUseCase(_NoExchanges()),
          rateUser: RateUserUseCase(_NoExchanges()),
        );

    test('the sublists are filtered once and reused while the sources stay the same', () {
      final lists = SellerHubLists();
      final acc = account();
      final materials = [
        _material('1', 'ana'),
        _material('2', 'ana', status: MaterialStatusEnum.SOLD),
        _material('3', 'luis'),
      ];
      final rooms = [
        ChatRoomEntity(id: 'r1', materialId: '1', buyerId: 'luis', sellerId: 'ana', createdAt: DateTime(2026)),
      ];

      for (var rebuild = 0; rebuild < 5; rebuild++) {
        lists.update(userId: 'ana', materials: materials, exchanges: acc.exchanges, rooms: rooms, account: acc);
      }

      expect(lists.myListings.map((m) => m.id), ['1', '2']);
      expect(lists.activeCount, 1);
      expect(lists.buyerChats, isEmpty); // no message yet
      expect(lists.listingsComputations, 1);
      expect(lists.salesComputations, 1);
      expect(lists.chatsComputations, 1);
    });

    test('a new list (or another user) recomputes only what depends on it', () {
      final lists = SellerHubLists();
      final acc = account();
      final rooms = <ChatRoomEntity>[];
      lists.update(userId: 'ana', materials: [_material('1', 'ana')], exchanges: acc.exchanges, rooms: rooms, account: acc);

      lists.update(
        userId: 'ana',
        materials: [_material('1', 'ana'), _material('4', 'ana')],
        exchanges: acc.exchanges,
        rooms: rooms,
        account: acc,
      );
      expect(lists.myListings, hasLength(2));
      expect(lists.listingsComputations, 2);
      expect(lists.salesComputations, 1);
      expect(lists.chatsComputations, 1);

      lists.update(userId: 'luis', materials: [_material('1', 'ana')], exchanges: acc.exchanges, rooms: rooms, account: acc);
      expect(lists.myListings, isEmpty);
      expect(lists.salesComputations, 2);
      expect(lists.chatsComputations, 2);
    });

    test('a new month refreshes "earned this month" even with the same exchanges', () {
      final lists = SellerHubLists();
      final acc = account();
      final materials = <MaterialEntity>[];
      final rooms = <ChatRoomEntity>[];
      lists.update(
          userId: 'ana', materials: materials, exchanges: acc.exchanges, rooms: rooms, account: acc, now: DateTime(2026, 11, 30));
      lists.update(
          userId: 'ana', materials: materials, exchanges: acc.exchanges, rooms: rooms, account: acc, now: DateTime(2026, 12, 1));

      expect(lists.salesComputations, 2);
      expect(lists.earnedThisMonth, 0);
    });
  });
}
