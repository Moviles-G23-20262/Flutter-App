import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/outbox_store.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/chat_agreement.dart';
import 'package:flutter_front_end/model/entities/chat_room_entity.dart';
import 'package:flutter_front_end/model/entities/conversation_insight.dart';
import 'package:flutter_front_end/model/entities/exchange_entity.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/meeting_point_density.dart';
import 'package:flutter_front_end/model/entities/meetup_entities.dart';
import 'package:flutter_front_end/model/entities/new_listing_data.dart';
import 'package:flutter_front_end/model/entities/notification_entity.dart';
import 'package:flutter_front_end/model/entities/pending_items.dart';
import 'package:flutter_front_end/model/entities/power_status.dart';
import 'package:flutter_front_end/model/entities/theme_preference.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/entities/wishlist_item_entity.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/repositories/appearance_repositories.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/conversation_insight_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/mobile_data_preference_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/impl/pending_listing_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/repositories/power_repositories.dart';
import 'package:flutter_front_end/model/services/outbox_sync_service.dart';
import 'package:flutter_front_end/model/use_cases/appearance_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/outbox_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_listing_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_message_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/power_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/view/screens/chat_view.dart';
import 'package:flutter_front_end/view/screens/home_screen.dart';
import 'package:flutter_front_end/view/screens/profile_screen.dart';
import 'package:flutter_front_end/view/screens/seller_hub_screen.dart';
import 'package:flutter_front_end/view/widgets/offline_banner.dart';
import 'package:flutter_front_end/view_model/account_view_model.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/chat_view_model.dart';
import 'package:flutter_front_end/view_model/connectivity_view_model.dart';
import 'package:flutter_front_end/view_model/marketplace_view_model.dart';
import 'package:flutter_front_end/view_model/power_view_model.dart';
import 'package:flutter_front_end/view_model/schedule_view_model.dart';
import 'package:flutter_front_end/view_model/theme_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestNetwork implements ConnectivityRepository, NetworkTransportRepository {
  bool online = true;
  NetworkTransport transport = NetworkTransport.wifi;
  final onlineController = StreamController<bool>.broadcast();
  final transportController = StreamController<NetworkTransport>.broadcast();

  void emitTransport(NetworkTransport next) {
    transport = next;
    online = next != NetworkTransport.none;
    onlineController.add(online);
    transportController.add(next);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => onlineController.stream;

  @override
  Future<NetworkTransport> currentTransport() async => transport;

  @override
  Stream<NetworkTransport> watchTransport() => transportController.stream;
}

class _FakeSender implements OutboxSender {
  final List<String> sent = [];
  final List<Object> failures = [];

  Future<void> _send(String label) async {
    if (failures.isNotEmpty) throw failures.removeAt(0);
    sent.add(label);
  }

  @override
  Future<String> uploadPhoto(String path) async => 'https://cdn.test/p.jpg';

  @override
  Future<void> createListing(Map<String, dynamic> body) => _send('listing:${body['title']}');

  @override
  Future<void> sendMessage(PendingMessage message) => _send('${message.chatRoomId}:${message.content}');

  @override
  Future<void> sendAction(PendingAction action) => _send('${action.kind.name}:${action.groupId}');
}

class _NoMaterials implements MaterialRepository {
  @override
  Future<List<MaterialEntity>> getMaterials() async => const [];

  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() async => const CachedList([]);

  @override
  Future<MaterialEntity> createListing(NewListingData data) => throw UnimplementedError();
  @override
  Future<MaterialEntity> updatePrice(String materialId, double newPrice) => throw UnimplementedError();
}

class _NoWishlist implements WishlistRepository {
  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() async => const CachedList([]);

  @override
  Future<WishlistItemEntity> add(String materialId) => throw UnimplementedError();

  @override
  Future<void> remove(String wishlistItemId) async {}
}

class _FakeChats implements ChatRepository {
  List<ChatRoomEntity> rooms = const [];
  final Map<String, List<MessageEntity>> serverMessages = {};

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async => rooms;

  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() async => CachedList(rooms);

  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) => throw UnimplementedError();

  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) async => serverMessages[chatRoomId] ?? const [];

  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) async =>
      CachedList(serverMessages[chatRoomId] ?? const []);

  @override
  Future<MessageEntity> sendMessage(String chatRoomId, String content, {String? id, DateTime? clientCreatedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> markRead(String chatRoomId) async {}
}

class _NoExchanges implements ExchangeRepository {
  @override
  Future<List<ExchangeEntity>> getExchanges() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoNotifications implements NotificationRepository {
  @override
  Future<CachedList<NotificationEntity>> getNotifications() async => const CachedList([]);

  @override
  Future<void> markOpened(String notificationId) async {}
}

class _NoMeetups implements MeetupRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoSchedule implements ScheduleRepository {
  @override
  Future<List<ScheduleBlockEntity>> getSchedule() async => const [];

  @override
  Future<ScheduleBlockEntity> add(NewScheduleBlock block) => throw UnimplementedError();

  @override
  Future<void> remove(String blockId) async {}
}

class _NoLocation implements LocationRepository {
  @override
  Future<GeoPoint?> currentLocation() async => null;
}

class _NoDensity implements MeetingDensityRepository {
  @override
  Future<MeetingPointDensity> getDensity() async => MeetingPointDensity.empty;
}

class _NoInsights implements ConversationInsightRepository {
  @override
  Future<ConversationInsight> getConversationInsight() async =>
      const ConversationInsight(conversationsAnalyzed: 0, medianMessages: 0, medianMinutes: 0);

  @override
  Future<ChatAgreement> getChatAgreement(String chatRoomId) => throw const ApiException(404, 'not ready');
}

class _NoTracker implements AnalyticsEventRepository {
  @override
  Future<void> track(AnalyticsEvent event) async {}
}

class _NoLight implements AmbientLightRepository {
  @override
  Stream<double> luxReadings() => const Stream.empty();
}

class _NoThemePrefs implements ThemePreferenceRepository {
  @override
  Future<ThemePreference?> load() async => ThemePreference.auto;

  @override
  Future<void> save(ThemePreference preference) async {}
}

class _NoBattery implements BatteryRepository {
  @override
  Stream<PowerStatus> watch() => const Stream.empty();
}

final _ana = UserEntity(
  id: 'ana',
  email: 'ana@uniandes.edu.co',
  fullName: 'Ana Gomez',
  major: 'ISIS',
  rating: 4.9,
  createdAt: DateTime(2026, 9, 1),
);

void _ignoreFontOverflows() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

class _MemoryOutboxStore implements OutboxStore {
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<PendingMessage> _messages = [];
  final List<PendingListing> _listings = [];
  final List<PendingAction> _actions = [];
  int _seq = 0;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<int> get pendingCountStream async* {
    yield await pendingCount();
    await for (final _ in _changes.stream) {
      yield await pendingCount();
    }
  }

  @override
  Future<int> pendingCount([String? ownerId]) async {
    final m = ownerId == null ? _messages.length : _messages.where((e) => e.ownerId == ownerId).length;
    final l = ownerId == null ? _listings.length : _listings.where((e) => e.ownerId == ownerId).length;
    final a = ownerId == null ? _actions.length : _actions.where((e) => e.ownerId == ownerId).length;
    return m + l + a;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<PendingMessage> enqueueMessage({
    required String ownerId,
    required String chatRoomId,
    required String content,
  }) async {
    final item = PendingMessage(
      id: 'msg-${++_seq}',
      ownerId: ownerId,
      chatRoomId: chatRoomId,
      content: content,
      createdAt: DateTime(2026, 9, 10, 10, _seq),
    );
    _messages.add(item);
    _emit();
    return item;
  }

  @override
  Future<List<PendingMessage>> messages(String ownerId, {String? chatRoomId}) async => _messages
      .where((m) => m.ownerId == ownerId && (chatRoomId == null || m.chatRoomId == chatRoomId))
      .toList(growable: false);

  @override
  Future<PendingListing> enqueueListing({
    required String ownerId,
    required Map<String, dynamic> payload,
    List<String> photoPaths = const [],
    String? id,
  }) async {
    final item = PendingListing(
      id: id ?? 'lst-${++_seq}',
      ownerId: ownerId,
      payload: Map<String, dynamic>.from(payload),
      photoPaths: List<String>.from(photoPaths),
      createdAt: DateTime(2026, 9, 10, 10, _seq),
    );
    _listings.add(item);
    _emit();
    return item;
  }

  @override
  Future<void> saveUploadedUrls(String listingId, List<String> urls) async {
    for (var i = 0; i < _listings.length; i++) {
      final l = _listings[i];
      if (l.id == listingId) {
        _listings[i] = PendingListing(
          id: l.id,
          ownerId: l.ownerId,
          payload: l.payload,
          photoPaths: l.photoPaths,
          uploadedUrls: List<String>.from(urls),
          createdAt: l.createdAt,
          status: l.status,
          attempts: l.attempts,
          lastError: l.lastError,
        );
      }
    }
    _emit();
  }

  @override
  Future<List<String>> photoPathsOf(String listingId) async =>
      _listings.where((l) => l.id == listingId).firstOrNull?.photoPaths ?? const [];

  @override
  Future<List<PendingListing>> listings(String ownerId) async =>
      _listings.where((l) => l.ownerId == ownerId).toList(growable: false);

  @override
  Future<List<PendingListing>> pendingListings(String ownerId) => listings(ownerId);

  @override
  Future<void> deleteListing(String id) => discard(PendingKind.listing, id);

  @override
  Future<PendingAction> enqueueAction({
    required String ownerId,
    required PendingActionKind kind,
    required String groupId,
    required Map<String, dynamic> payload,
  }) async {
    final item = PendingAction(
      id: 'act-${++_seq}',
      ownerId: ownerId,
      kind: kind,
      groupId: groupId,
      payload: Map<String, dynamic>.from(payload),
      createdAt: DateTime(2026, 9, 10, 10, _seq),
    );
    _actions.add(item);
    _emit();
    return item;
  }

  @override
  Future<List<PendingAction>> actions(String ownerId) async =>
      _actions.where((a) => a.ownerId == ownerId).toList(growable: false);

  @override
  Future<void> markSent(PendingKind kind, String id) => discard(kind, id);

  @override
  Future<void> markRetry(PendingKind kind, String id, String reason) async {
    _update(kind, id, (status, attempts, _) => (status, attempts + 1, reason));
  }

  @override
  Future<void> markRefused(PendingKind kind, String id, String reason) async {
    _update(kind, id, (_, attempts, _) => (PendingStatus.refused, attempts + 1, reason));
  }

  @override
  Future<void> retry(PendingKind kind, String id) async {
    _update(kind, id, (_, attempts, _) => (PendingStatus.waiting, attempts, null));
  }

  void _update(
    PendingKind kind,
    String id,
    (PendingStatus, int, String?) Function(PendingStatus, int, String?) next,
  ) {
    switch (kind) {
      case PendingKind.message:
        for (var i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          if (m.id == id) {
            final (status, attempts, err) = next(m.status, m.attempts, m.lastError);
            _messages[i] = PendingMessage(
              id: m.id,
              ownerId: m.ownerId,
              chatRoomId: m.chatRoomId,
              content: m.content,
              createdAt: m.createdAt,
              status: status,
              attempts: attempts,
              lastError: err,
            );
          }
        }
      case PendingKind.listing:
        for (var i = 0; i < _listings.length; i++) {
          final l = _listings[i];
          if (l.id == id) {
            final (status, attempts, err) = next(l.status, l.attempts, l.lastError);
            _listings[i] = PendingListing(
              id: l.id,
              ownerId: l.ownerId,
              payload: l.payload,
              photoPaths: l.photoPaths,
              uploadedUrls: l.uploadedUrls,
              createdAt: l.createdAt,
              status: status,
              attempts: attempts,
              lastError: err,
            );
          }
        }
      case PendingKind.action:
        for (var i = 0; i < _actions.length; i++) {
          final a = _actions[i];
          if (a.id == id) {
            final (status, attempts, err) = next(a.status, a.attempts, a.lastError);
            _actions[i] = PendingAction(
              id: a.id,
              ownerId: a.ownerId,
              kind: a.kind,
              groupId: a.groupId,
              payload: a.payload,
              createdAt: a.createdAt,
              status: status,
              attempts: attempts,
              lastError: err,
            );
          }
        }
    }
    _emit();
  }

  @override
  Future<void> discard(PendingKind kind, String id) async {
    switch (kind) {
      case PendingKind.message:
        _messages.removeWhere((m) => m.id == id);
      case PendingKind.listing:
        _listings.removeWhere((l) => l.id == id);
      case PendingKind.action:
        _actions.removeWhere((a) => a.id == id);
    }
    _emit();
  }

  @override
  Future<void> dispose() => _changes.close();
}

void main() {
  sqfliteFfiInit();

  group('EC13 optional mobile data (allow_mobile_data)', () {
    late AppDatabase db;
    late OutboxStore store;
    late _FakeSender sender;
    late _TestNetwork network;
    late MobileDataPreferenceRepositoryImpl prefs;
    late OutboxSyncService sync;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.withFactory(databaseFactoryFfi);
      store = OutboxStore(db);
      sender = _FakeSender();
      network = _TestNetwork();
      prefs = MobileDataPreferenceRepositoryImpl();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: network,
        transport: network,
        mobileDataPreference: prefs,
        baseRetryDelay: const Duration(hours: 1),
      );
    });

    tearDown(() async {
      sync.dispose();
      await db.close();
    });

    test('allow_mobile_data defaults to false and persists changes', () async {
      expect(await prefs.isAllowed(), isFalse);
      await prefs.setAllowed(true);
      expect(await MobileDataPreferenceRepositoryImpl().isAllowed(), isTrue);
    });

    test('pauses outbox on mobile data when disabled and resumes on Wi-Fi without backoff retry', () async {
      network.transport = NetworkTransport.mobile;
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'queued on cellular');

      sync.start('ana');
      await sync.flush();

      expect(sender.sent, isEmpty);
      expect(sync.isWaitingForWifi, isTrue);
      expect(sync.retryScheduled, isFalse);

      network.emitTransport(NetworkTransport.wifi);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sender.sent, ['r1:queued on cellular']);
      expect(sync.isWaitingForWifi, isFalse);
    });

    test('one-shot overMobileData flush sends once without toggling preference', () async {
      network.transport = NetworkTransport.mobile;
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'urgent send');

      sync.start('ana');
      await sync.flush();
      expect(sync.isWaitingForWifi, isTrue);

      await sync.flush(overMobileData: true);

      expect(sender.sent, ['r1:urgent send']);
      expect(sync.isWaitingForWifi, isFalse);
      expect(await prefs.isAllowed(), isFalse);
    });

    test('empty outbox on mobile data never enters waitingForWifi state', () async {
      network.transport = NetworkTransport.mobile;

      sync.start('ana');
      await sync.flush();

      expect(sync.isWaitingForWifi, isFalse);
    });

    test('discarding the only waiting message clears waitingForWifi', () async {
      network.transport = NetworkTransport.mobile;
      final msg = await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'wait');

      sync.start('ana');
      await sync.flush();
      expect(sync.isWaitingForWifi, isTrue);

      await store.discard(PendingKind.message, msg.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sync.isWaitingForWifi, isFalse);
    });
  });

  group('EC7 Retry and Delete on refused outbox items', () {
    late AppDatabase db;
    late OutboxStore store;
    late _FakeSender sender;
    late _TestNetwork network;
    late OutboxSyncService sync;

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      store = OutboxStore(db);
      sender = _FakeSender();
      network = _TestNetwork();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: network,
        baseRetryDelay: const Duration(hours: 1),
      );
    });

    tearDown(() async {
      sync.dispose();
      await db.close();
    });

    test('RetryPendingMessageUseCase resets refused message and delivers blocked queue in order', () async {
      final first = await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'first');
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'second');
      sender.failures.add(const ApiException(400, 'Too fast'));

      sync.start('ana');
      await sync.flush();
      expect(sender.sent, isEmpty);
      expect((await store.messages('ana')).first.status, PendingStatus.refused);

      await RetryPendingMessageUseCase(store, sync).execute(first.id);

      expect(sender.sent, ['r1:first', 'r1:second']);
      expect(await store.messages('ana'), isEmpty);
    });

    test('DeletePendingMessageUseCase removes refused head message and unblocks the next one', () async {
      final first = await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'bad');
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'good');
      sender.failures.add(const ApiException(403, 'Blocked'));

      sync.start('ana');
      await sync.flush();

      await DeletePendingMessageUseCase(store, sync).execute(first.id);

      expect(sender.sent, ['r1:good']);
      expect(await store.messages('ana'), isEmpty);
    });

    test('PendingListingRepositoryImpl.retry moves a refused listing back to waiting and sends it', () async {
      final repo = PendingListingRepositoryImpl(store, sync: sync);
      sender.failures.add(const ApiException(400, 'Price invalid'));
      final queued = await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calc', 'price': '10000'});

      sync.start('ana');
      await sync.flush();
      expect((await store.listings('ana')).single.status, PendingStatus.refused);

      await repo.retry(queued.id);

      expect(sender.sent, ['listing:Calc']);
      expect(await store.listings('ana'), isEmpty);
    });
  });

  group('UI widgets for EC13 & EC7', () {
    late _MemoryOutboxStore store;
    late _FakeSender sender;
    late _TestNetwork network;
    late MobileDataPreferenceRepositoryImpl prefs;
    late OutboxSyncService sync;
    late _FakeChats fakeChats;
    late AppViewModel appState;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _MemoryOutboxStore();
      sender = _FakeSender();
      network = _TestNetwork();
      prefs = MobileDataPreferenceRepositoryImpl();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: network,
        transport: network,
        mobileDataPreference: prefs,
        baseRetryDelay: const Duration(hours: 1),
      );
      fakeChats = _FakeChats();
      final pendingListings = PendingListingRepositoryImpl(store, sync: sync);
      final meetups = MeetupUseCases(
        getMeetingPoints: GetMeetingPointsUseCase(_NoMeetups()),
        getSuggestions: GetMeetingSuggestionsUseCase(_NoMeetups()),
        propose: ProposeMeetingUseCase(_NoMeetups()),
        answer: AnswerMeetingProposalUseCase(_NoMeetups()),
        currentLocation: GetCurrentLocationUseCase(_NoLocation()),
        rankZones: RankSafeZonesUseCase(),
        recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
        getDensity: GetMeetingPointDensityUseCase(_NoDensity()),
      );
      final syncOutbox = SyncOutboxUseCase(sync);
      appState = AppViewModel(
        marketplace: MarketplaceViewModel(
          getMaterials: GetMaterialsUseCase(_NoMaterials()),
          createListing: CreateListingUseCase(_NoMaterials()),
          getWishlist: GetWishlistUseCase(_NoWishlist()),
          addToWishlist: AddToWishlistUseCase(_NoWishlist()),
          removeFromWishlist: RemoveFromWishlistUseCase(_NoWishlist()),
          watchPendingListings: WatchPendingListingsUseCase(pendingListings),
          retryPendingListing: RetryPendingListingUseCase(pendingListings),
          discardPendingListing: DiscardPendingListingUseCase(pendingListings),
        ),
        chats: ChatViewModel(
          getChatRooms: GetChatRoomsUseCase(fakeChats),
          openChatRoom: OpenChatRoomUseCase(fakeChats),
          getMessages: GetMessagesUseCase(fakeChats),
          sendMessage: SendMessageUseCase(fakeChats),
          markRead: MarkChatReadUseCase(fakeChats),
          answerProposal: meetups.answer,
          getConversationInsight: GetConversationInsightUseCase(_NoInsights()),
          queueMessage: QueueMessageUseCase(store, sync),
          retryPendingMessage: RetryPendingMessageUseCase(store, sync),
          deletePendingMessage: DeletePendingMessageUseCase(store, sync),
          getPendingMessages: GetPendingMessagesUseCase(store),
          watchPendingCount: WatchPendingCountUseCase(store),
          getChatAgreement: GetChatAgreementUseCase(_NoInsights()),
          trackEvent: TrackEventUseCase(_NoTracker()),
        ),
        account: AccountViewModel(
          getExchanges: GetExchangesUseCase(_NoExchanges()),
          getNotifications: GetNotificationsUseCase(_NoNotifications()),
          markNotificationOpened: MarkNotificationOpenedUseCase(_NoNotifications()),
          placeOrder: PlaceOrderUseCase(_NoExchanges()),
          completeExchange: CompleteExchangeUseCase(_NoExchanges()),
          cancelExchange: CancelExchangeUseCase(_NoExchanges()),
          rateUser: RateUserUseCase(_NoExchanges()),
        ),
        schedule: ScheduleViewModel(
          getSchedule: GetScheduleUseCase(_NoSchedule()),
          addBlock: AddScheduleBlockUseCase(_NoSchedule()),
          removeBlock: RemoveScheduleBlockUseCase(_NoSchedule()),
        ),
        meetups: meetups,
        theme: ThemeViewModel(
          watchAmbientLight: WatchAmbientLightUseCase(_NoLight()),
          loadPreference: LoadThemePreferenceUseCase(_NoThemePrefs()),
          savePreference: SaveThemePreferenceUseCase(_NoThemePrefs()),
        ),
        power: PowerViewModel(watchBattery: WatchBatteryUseCase(_NoBattery())),
        connectivity: ConnectivityViewModel(
          getConnectivity: GetConnectivityUseCase(network),
          watchConnectivity: WatchConnectivityUseCase(network),
          getTransport: GetNetworkTransportUseCase(network),
          watchTransport: WatchNetworkTransportUseCase(network),
          loadAllowMobileData: LoadAllowMobileDataUseCase(prefs),
          saveAllowMobileData: SaveAllowMobileDataUseCase(prefs),
          watchWaitingForWifi: WatchWaitingForWifiUseCase(sync),
          onAllowMobileDataEnabled: () => syncOutbox.execute(),
        ),
        trackEvent: TrackEventUseCase(_NoTracker()),
        startOutboxSync: StartOutboxSyncUseCase(sync),
        stopOutboxSync: StopOutboxSyncUseCase(sync),
        syncOutbox: syncOutbox,
      );
    });

    tearDown(() async {
      appState.chats.clear();
      appState.dispose();
      sync.dispose();
      await store.dispose();
    });

    testWidgets('ProfileScreen toggles Use mobile data and HomeScreen shows Waiting for Wi-Fi Send now', (tester) async {
      _ignoreFontOverflows();
      network.transport = NetworkTransport.mobile;
      await store.enqueueMessage(ownerId: _ana.id, chatRoomId: 'r1', content: 'waiting item');

      appState.connectivity.start();
      appState.login(_ana);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(appState.connectivity.isWaitingForWifi, isTrue);

      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(appState: appState))));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text("Waiting for Wi-Fi. Turn on 'Use mobile data' in Profile to send now."), findsOneWidget);

      await tester.tap(find.text('Send now'));
      await tester.pumpAndSettle();

      expect(sender.sent, ['r1:waiting item']);
      expect(appState.connectivity.isWaitingForWifi, isFalse);

      // Re-queue over cellular and turn on "Use mobile data" in Profile
      await store.enqueueMessage(ownerId: _ana.id, chatRoomId: 'r1', content: 'from profile toggle');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(appState.connectivity.isWaitingForWifi, isTrue);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfileScreen(appState: appState))));
      await tester.pumpAndSettle();

      expect(find.text('Use mobile data'), findsOneWidget);
      await tester.tap(find.byKey(const Key('allow-mobile-data-toggle')));
      await tester.pumpAndSettle();

      expect(appState.connectivity.allowMobileData, isTrue);
      expect(await prefs.isAllowed(), isTrue);
      expect(sender.sent, ['r1:waiting item', 'r1:from profile toggle']);
      appState.chats.clear();
    });

    testWidgets('ChatView displays Not sent + Retry + Delete on failed bubble and SellerHub shows Retry on refused listing', (tester) async {
      _ignoreFontOverflows();
      const seller = UserSummary(id: 'seller-2', fullName: 'Carlos Ruiz', major: 'ISIS', rating: 4.5);
      final room = ChatRoomEntity(
        id: 'r1',
        materialId: 'm1',
        buyerId: _ana.id,
        sellerId: 'seller-2',
        createdAt: DateTime(2026, 9, 10, 10),
        buyer: const UserSummary(id: 'ana', fullName: 'Ana Gomez', major: 'ISIS', rating: 4.9),
        seller: seller,
      );
      fakeChats.rooms = [room];

      final m1 = await store.enqueueMessage(ownerId: _ana.id, chatRoomId: 'r1', content: 'Retried text');
      final m2 = await store.enqueueMessage(ownerId: _ana.id, chatRoomId: 'r1', content: 'Deleted text');
      await store.markRefused(PendingKind.message, m1.id, 'Rate limited');
      await store.markRefused(PendingKind.message, m2.id, 'Invalid');

      final pendingListing = await store.enqueueListing(ownerId: _ana.id, payload: {'title': 'Lab coat', 'price': '45000'});
      await store.markRefused(PendingKind.listing, pendingListing.id, 'Missing photo');

      appState.connectivity.start();
      appState.login(_ana);
      appState.chats.openRoom('r1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ChatView(appState: appState, room: room))));
      await tester.pumpAndSettle();

      expect(find.text('Not sent · Rate limited'), findsOneWidget);
      expect(find.byKey(Key('retry-message-${m1.id}')), findsOneWidget);
      expect(find.byKey(Key('delete-message-${m2.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('retry-message-${m1.id}')));
      await tester.pumpAndSettle();
      expect(sender.sent, contains('r1:Retried text'));

      await tester.tap(find.byKey(Key('delete-message-${m2.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Deleted text'), findsNothing);

      appState.chats.closeRoom();

      await tester.pumpWidget(MaterialApp(home: SellerHubScreen(appState: appState)));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('retry-pending-listing-${pendingListing.id}')), findsOneWidget);
      expect(find.byKey(Key('discard-pending-listing-${pendingListing.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('retry-pending-listing-${pendingListing.id}')));
      await tester.pumpAndSettle();

      expect(sender.sent, contains('listing:Lab coat'));
      expect(find.byKey(Key('pending-listing-${pendingListing.id}')), findsNothing);
      appState.chats.clear();
    });
  });
}
