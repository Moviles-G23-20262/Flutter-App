import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/connectivity_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/outbox_store.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/chat_agreement.dart';
import 'package:flutter_front_end/model/entities/chat_room_entity.dart';
import 'package:flutter_front_end/model/entities/conversation_insight.dart';
import 'package:flutter_front_end/model/entities/pending_items.dart';
import 'package:flutter_front_end/model/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/conversation_insight_repository.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/services/outbox_sync_service.dart';
import 'package:flutter_front_end/model/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_message_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/view_model/chat_view_model.dart';
import 'package:flutter_front_end/view_model/connectivity_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestConnectivity implements ConnectivityRepository, NetworkTransportRepository {
  bool online = false;
  NetworkTransport transport = NetworkTransport.none;
  final onlineController = StreamController<bool>.broadcast();
  final transportController = StreamController<NetworkTransport>.broadcast();

  void setOnlineWifi() {
    online = true;
    transport = NetworkTransport.wifi;
    onlineController.add(true);
    transportController.add(NetworkTransport.wifi);
  }

  void setOffline() {
    online = false;
    transport = NetworkTransport.none;
    onlineController.add(false);
    transportController.add(NetworkTransport.none);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => onlineController.stream;

  @override
  Future<NetworkTransport> currentTransport() async => transport;

  @override
  Stream<NetworkTransport> watchTransport() => transportController.stream;

  void dispose() {
    onlineController.close();
    transportController.close();
  }
}

class _ControlledSender implements OutboxSender {
  Completer<void>? inFlightFailure;
  int failCount = 0;
  final List<PendingMessage> delivered = [];

  @override
  Future<void> sendMessage(PendingMessage message) async {
    final gate = inFlightFailure;
    if (gate != null) {
      inFlightFailure = null;
      await gate.future;
      throw const NetworkException('offline');
    }
    if (failCount > 0) {
      failCount--;
      throw const NetworkException('dns warming up');
    }
    delivered.add(message);
  }

  @override
  Future<String> uploadPhoto(String path) async => 'https://cdn.test/x.jpg';

  @override
  Future<void> createListing(Map<String, dynamic> body) async {}

  @override
  Future<void> sendAction(PendingAction action) async {}
}

class _FakeChatRepo implements ChatRepository {
  bool throwOffline = false;
  final Map<String, List<MessageEntity>> serverMessages = {};

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async => const [];

  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() async => const CachedList([]);

  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) => throw UnimplementedError();

  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) async => serverMessages[chatRoomId] ?? const [];

  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) async {
    if (throwOffline) throw const NoConnectionException();
    return CachedList(serverMessages[chatRoomId] ?? const []);
  }

  @override
  Future<MessageEntity> sendMessage(String chatRoomId, String content, {String? id, DateTime? clientCreatedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> markRead(String chatRoomId) async {}
}

class _StubMeetupRepo implements MeetupRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubInsightRepo implements ConversationInsightRepository {
  @override
  Future<ConversationInsight> getConversationInsight() async =>
      const ConversationInsight(conversationsAnalyzed: 0, medianMessages: 0, medianMinutes: 0);

  @override
  Future<ChatAgreement> getChatAgreement(String chatRoomId) => throw const NoConnectionException();
}

class _StubAnalyticsRepo implements AnalyticsEventRepository {
  @override
  Future<void> track(AnalyticsEvent event) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ConnectivityDataSource transport filtering', () {
    test('Bluetooth alone in Airplane Mode is treated as offline', () {
      expect(ConnectivityDataSource.isOnlineResults([ConnectivityResult.bluetooth]), isFalse);
      expect(ConnectivityDataSource.transportFromResults([ConnectivityResult.bluetooth]), NetworkTransport.none);
      expect(ConnectivityDataSource.isOnlineResults([ConnectivityResult.none]), isFalse);
      expect(ConnectivityDataSource.isOnlineResults([ConnectivityResult.wifi]), isTrue);
      expect(ConnectivityDataSource.transportFromResults([ConnectivityResult.wifi]), NetworkTransport.wifi);
      expect(ConnectivityDataSource.isOnlineResults([ConnectivityResult.mobile]), isTrue);
      expect(ConnectivityDataSource.transportFromResults([ConnectivityResult.mobile]), NetworkTransport.mobile);
    });
  });

  group('ApiClient IO error handling & reachability callbacks', () {
    test('converts SocketException and HandshakeException to NetworkException and notifies callbacks', () async {
      var errors = 0;
      var successes = 0;
      var mode = 'socket';

      final api = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async {
          if (mode == 'socket') throw const SocketException('Failed host lookup');
          if (mode == 'tls') throw const HandshakeException('TLS failed');
          return http.Response('{"ok":true}', 200);
        }),
      )
        ..onNetworkError = (() {
          errors++;
        })
        ..onNetworkSuccess = (() {
          successes++;
        });

      await expectLater(api.get('/ping'), throwsA(isA<NetworkException>()));
      mode = 'tls';
      await expectLater(api.get('/ping'), throwsA(isA<NetworkException>()));
      expect(errors, 2);
      expect(successes, 0);

      mode = 'ok';
      final body = await api.get('/ping');
      expect(body, {'ok': true});
      expect(successes, 1);
    });

    test('ConnectivityViewModel reflects real reachability via reportNetworkError/Success', () async {
      final net = _TestConnectivity()..online = true;
      final vm = ConnectivityViewModel(
        getConnectivity: GetConnectivityUseCase(net),
        watchConnectivity: WatchConnectivityUseCase(net),
      )..start();
      await Future<void>.delayed(Duration.zero);
      expect(vm.isOnline, isTrue);

      vm.reportNetworkError();
      expect(vm.isOffline, isTrue);

      vm.reportNetworkSuccess();
      expect(vm.isOnline, isTrue);

      vm.dispose();
      net.dispose();
    });
  });

  group('OutboxSyncService Wi-Fi reconnect reliability', () {
    late AppDatabase db;
    late OutboxStore store;
    late _TestConnectivity net;
    late _ControlledSender sender;
    late OutboxSyncService sync;

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      store = OutboxStore(db);
      net = _TestConnectivity();
      sender = _ControlledSender();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: net,
        transport: net,
        baseRetryDelay: const Duration(minutes: 2),
        reconnectRetryDelay: const Duration(milliseconds: 40),
      );
    });

    tearDown(() async {
      sync.dispose();
      net.dispose();
      await store.dispose();
      await db.close();
    });

    test('resends immediately when Wi-Fi returns while an earlier offline attempt is still failing', () async {
      sync.start('u1');
      await store.enqueueMessage(ownerId: 'u1', chatRoomId: 'r1', content: 'Hello offline');

      // Start an offline attempt that is still in flight when Wi-Fi returns.
      final gate = Completer<void>();
      sender.inFlightFailure = gate;
      final firstFlush = sync.flush();
      await Future<void>.delayed(Duration.zero);

      // Wi-Fi reconnects while the old offline request is still pending.
      net.setOnlineWifi();
      // Now the old offline request finishes failing.
      gate.complete();
      await firstFlush;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sender.delivered.map((m) => m.content), ['Hello offline']);
      expect(await store.messages('u1'), isEmpty);
    });

    test('uses fast reconnect retry when first post-Wi-Fi attempt hits brief DNS failure', () async {
      sync.start('u1');
      await store.enqueueMessage(ownerId: 'u1', chatRoomId: 'r1', content: 'After DNS');

      // First attempt right on Wi-Fi reconnect fails due to brief DNS warm-up, second succeeds.
      sender.failCount = 1;
      net.setOnlineWifi();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(sender.delivered.map((m) => m.content), ['After DNS']);
      expect(await store.messages('u1'), isEmpty);
    });
  });

  group('ChatViewModel pending visibility & auto-refresh after outbox delivery', () {
    late AppDatabase db;
    late OutboxStore store;
    late _TestConnectivity net;
    late _ControlledSender sender;
    late OutboxSyncService sync;
    late _FakeChatRepo repo;
    late ChatViewModel vm;

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      store = OutboxStore(db);
      net = _TestConnectivity();
      sender = _ControlledSender();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: net,
        transport: net,
        baseRetryDelay: const Duration(minutes: 2),
        reconnectRetryDelay: const Duration(milliseconds: 30),
      );
      repo = _FakeChatRepo();
      vm = ChatViewModel(
        getChatRooms: GetChatRoomsUseCase(repo),
        openChatRoom: OpenChatRoomUseCase(repo),
        getMessages: GetMessagesUseCase(repo),
        sendMessage: SendMessageUseCase(repo),
        markRead: MarkChatReadUseCase(repo),
        answerProposal: AnswerMeetingProposalUseCase(_StubMeetupRepo()),
        getConversationInsight: GetConversationInsightUseCase(_StubInsightRepo()),
        getChatAgreement: GetChatAgreementUseCase(_StubInsightRepo()),
        trackEvent: TrackEventUseCase(_StubAnalyticsRepo()),
        queueMessage: QueueMessageUseCase(store, sync),
        retryPendingMessage: RetryPendingMessageUseCase(store, sync),
        deletePendingMessage: DeletePendingMessageUseCase(store, sync),
        getPendingMessages: GetPendingMessagesUseCase(store),
        watchPendingCount: WatchPendingCountUseCase(store),
      );
    });

    tearDown(() async {
      vm.dispose();
      sync.dispose();
      net.dispose();
      await store.dispose();
      await db.close();
    });

    test('shows queued message offline even if thread had no cache, and updates to sent on Wi-Fi return', () async {
      sync.start('u1');
      vm.start('u1');
      vm.setOffline(true);
      repo.throwOffline = true;
      sender.failCount = 1;

      vm.openRoom('r1');
      await Future<void>.delayed(Duration.zero);

      await vm.send('r1', 'Meet at ML');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Re-refreshing offline without server cache still displays the queued message with clock icon.
      await vm.refreshMessages();
      expect(vm.messagesOf('r1'), hasLength(1));
      expect(vm.messagesOf('r1').single.content, 'Meet at ML');
      expect(vm.messagesOf('r1').single.isPending, isTrue);

      // Now Wi-Fi comes back and the server has the delivered message.
      repo.throwOffline = false;
      final sentId = vm.messagesOf('r1').single.id;
      repo.serverMessages['r1'] = [
        MessageEntity(
          id: sentId,
          chatRoomId: 'r1',
          senderId: 'u1',
          content: 'Meet at ML',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];
      net.setOnlineWifi();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(sender.delivered, hasLength(1));
      expect(vm.messagesOf('r1').single.isPending, isFalse);
    });
  });

  group('User-friendly offline error messages', () {
    test('AuthNetworkException and NoConnectionException mention Wi-Fi / internet, not server/backend', () {
      const authErr = AuthNetworkException();
      const dataErr = NoConnectionException();
      expect(authErr.message.toLowerCase(), contains('wi-fi'));
      expect(authErr.message.toLowerCase(), isNot(contains('server')));
      expect(authErr.message.toLowerCase(), isNot(contains('backend')));
      expect(dataErr.message.toLowerCase(), contains('wi-fi'));
    });
  });
}
