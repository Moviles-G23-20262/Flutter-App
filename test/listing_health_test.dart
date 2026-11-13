import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/core/isolates/listing_health_analyzer.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/outbox_store.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/data_sources/marketplace_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/meetup_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/remote_outbox_sender.dart';
import 'package:flutter_front_end/model/dto/dead_listings_model.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/chat_agreement.dart';
import 'package:flutter_front_end/model/entities/chat_room_entity.dart';
import 'package:flutter_front_end/model/entities/conversation_insight.dart';
import 'package:flutter_front_end/model/entities/dead_listings_insight.dart';
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
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/repositories/appearance_repositories.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/conversation_insight_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/listing_health_preferences_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/impl/listing_health_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/impl/mobile_data_preference_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/impl/pending_action_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/listing_health_repository.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/repositories/power_repositories.dart';
import 'package:flutter_front_end/model/services/outbox_sync_service.dart';
import 'package:flutter_front_end/model/use_cases/appearance_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/listing_health_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_action_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_message_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/power_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/view/screens/listing_health_screen.dart';
import 'package:flutter_front_end/view/screens/seller_hub_screen.dart';
import 'package:flutter_front_end/view/widgets/offline_banner.dart';
import 'package:flutter_front_end/view_model/account_view_model.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/chat_view_model.dart';
import 'package:flutter_front_end/view_model/connectivity_view_model.dart';
import 'package:flutter_front_end/view_model/listing_health_view_model.dart';
import 'package:flutter_front_end/view_model/marketplace_view_model.dart';
import 'package:flutter_front_end/view_model/power_view_model.dart';
import 'package:flutter_front_end/view_model/schedule_view_model.dart';
import 'package:flutter_front_end/view_model/theme_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _bq10Json({int staleDays = 14, String sellerId = 'ana-id'}) => {
      'summary': {
        'total_listings': 18,
        'sold_listings': 6,
        'reserved_listings': 1,
        'active_fresh_listings': 6,
        'dead_listings': 5,
        'skipped': 0,
        'stale_days': staleDays,
        'dead_share': 0.42,
        'never_sold_share': 0.67,
        'median_days_active_dead': 22.5,
        'mean_days_active_dead': 24.0,
        'median_days_to_sell': 11.5,
      },
      'survival_curve': [
        {'day': 0, 'at_risk': 18, 'sold_cumulative': 0, 'survival_rate': 1.0},
        {'day': 7, 'at_risk': 14, 'sold_cumulative': 2, 'survival_rate': 0.89},
        {'day': 14, 'at_risk': 10, 'sold_cumulative': 4, 'survival_rate': 0.67},
        {'day': 30, 'at_risk': 5, 'sold_cumulative': 5, 'survival_rate': 0.41},
        {'day': 60, 'at_risk': 2, 'sold_cumulative': 6, 'survival_rate': 0.25},
      ],
      'clusters': [
        {
          'cluster_id': 'cluster-overpriced',
          'label': 'Overpriced Textbooks',
          'recommended_action': 'Cut price toward market median and add a clear photo.',
          'count': 3,
          'share': 0.6,
          'avg_price_ratio': 1.52,
          'median_price_ratio': 1.50,
          'avg_photos': 1.0,
          'avg_seller_rating': 4.1,
          'avg_days_active': 24.0,
          'median_days_active': 22.0,
          'zero_contact_share': 1.0,
          'top_category': 'BOOKS',
        },
        {
          'cluster_id': 'cluster-low-trust',
          'label': 'Low-Photo Gadgets',
          'recommended_action': 'Upload 2-3 bright photos showing condition.',
          'count': 2,
          'share': 0.4,
          'avg_price_ratio': 1.12,
          'median_price_ratio': 1.10,
          'avg_photos': 0.5,
          'avg_seller_rating': 3.2,
          'avg_days_active': 18.0,
          'median_days_active': 18.0,
          'zero_contact_share': 1.0,
          'top_category': 'CALCULATORS',
        },
      ],
      'dead_listings': [
        {
          'id': '00000000-0000-4000-8000-00000000d001',
          'title': 'Linear Algebra 5th Ed',
          'category': 'BOOKS',
          'price': 90000,
          'category_median_price': 55000,
          'price_ratio': 1.636,
          'suggested_price': 52200,
          'recommended_drop_pct': 42.0,
          'photos': 1,
          'contacts': 0,
          'seller_id': sellerId,
          'seller_rating': 4.6,
          'days_active': 21.0,
          'is_dead': true,
          'cluster_id': 'cluster-overpriced',
          'cluster_label': 'Overpriced Textbooks',
          'risk_score': 82,
          'risk_level': 'high',
          'reasons': ['Priced 64% above category median', 'Only 1 photo'],
          'recommendation': 'Drop price to \$52.200 COP and add a clear photo.',
        },
      ],
      'at_risk_listings': [
        {
          'id': '00000000-0000-4000-8000-00000000d001',
          'title': 'Linear Algebra 5th Ed',
          'category': 'BOOKS',
          'price': 90000,
          'category_median_price': 55000,
          'price_ratio': 1.636,
          'suggested_price': 52200,
          'recommended_drop_pct': 42.0,
          'photos': 1,
          'contacts': 0,
          'seller_id': sellerId,
          'seller_rating': 4.6,
          'days_active': 21.0,
          'is_dead': true,
          'cluster_id': 'cluster-overpriced',
          'cluster_label': 'Overpriced Textbooks',
          'risk_score': 82,
          'risk_level': 'high',
          'reasons': ['Priced 64% above category median', 'Only 1 photo'],
          'recommendation': 'Drop price to \$52.200 COP and add a clear photo.',
        },
        {
          'id': '00000000-0000-4000-8000-00000000d002',
          'title': 'Casio fx-991EX',
          'category': 'CALCULATORS',
          'price': 65000,
          'category_median_price': 50000,
          'price_ratio': 1.3,
          'suggested_price': 50000,
          'recommended_drop_pct': 23.1,
          'photos': 2,
          'contacts': 0,
          'seller_id': sellerId,
          'seller_rating': 4.6,
          'days_active': 9.0,
          'is_dead': false,
          'cluster_id': 'cluster-low-trust',
          'cluster_label': 'Low-Photo Gadgets',
          'risk_score': 45,
          'risk_level': 'medium',
          'reasons': ['Priced 30% above category median'],
          'recommendation': 'Lower price near market median.',
        },
      ],
      'seller_summary': {
        'seller_id': sellerId,
        'total_listings': 2,
        'sold_listings': 0,
        'reserved_listings': 0,
        'active_fresh_listings': 1,
        'dead_listings': 1,
        'at_risk_count': 2,
        'healthy_listings': 0,
      },
    };

Map<String, dynamic> _materialPayload(String id, {double price = 90000, String sellerId = 'ana-id'}) => {
      'id': id,
      'title': 'Linear Algebra 5th Ed',
      'description': 'Clean pages',
      'price': price.toStringAsFixed(2),
      'status': 'AVAILABLE',
      'imageUrls': ['https://cdn.test/book.jpg'],
      'sellerId': sellerId,
      'category': 'BOOKS',
      'createdAt': '2026-10-18T12:00:00Z',
      'updatedAt': '2026-11-10T10:00:00Z',
    };

MaterialEntity _material(
  String id, {
  String title = 'Linear Algebra 5th Ed',
  double price = 90000,
  String sellerId = 'ana-id',
  MaterialCategoryEnum category = MaterialCategoryEnum.BOOKS,
  List<String> imageUrls = const ['https://cdn.test/book.jpg'],
  DateTime? createdAt,
}) =>
    MaterialEntity(
      id: id,
      title: title,
      description: 'Clean pages',
      price: price,
      condition: MaterialConditionEnum.GOOD,
      status: MaterialStatusEnum.AVAILABLE,
      imageUrls: imageUrls,
      sellerId: sellerId,
      seller: const UserSummary(id: 'ana-id', fullName: 'Ana Gomez', major: 'ISIS', rating: 4.6),
      category: category,
      createdAt: createdAt ?? DateTime.utc(2026, 10, 18),
      updatedAt: DateTime.utc(2026, 11, 10),
    );

class _FakeListingHealthRepo implements ListingHealthRepository {
  CachedResult<DeadListingsInsight>? nextResult;
  Object? nextError;
  int calls = 0;
  int? lastStaleDays;

  @override
  Future<CachedResult<DeadListingsInsight>> getDeadListings({int staleDays = 14, String? sellerId}) async {
    calls++;
    lastStaleDays = staleDays;
    if (nextError != null) throw nextError!;
    return nextResult ?? CachedResult.fresh(DeadListingsModel.fromJson(_bq10Json(staleDays: staleDays)));
  }
}

class _FakeMaterialRepo implements MaterialRepository {
  List<MaterialEntity> items;
  Object? updateError;
  final List<(String, double)> updates = [];

  _FakeMaterialRepo([List<MaterialEntity>? initial]) : items = initial ?? [];

  @override
  Future<List<MaterialEntity>> getMaterials() async => items;

  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() async => CachedList(items);

  @override
  Future<MaterialEntity> createListing(NewListingData data) => throw UnimplementedError();

  @override
  Future<MaterialEntity> updatePrice(String materialId, double newPrice) async {
    if (updateError != null) throw updateError!;
    updates.add((materialId, newPrice));
    final idx = items.indexWhere((m) => m.id == materialId);
    final updated = (idx >= 0 ? items[idx] : _material(materialId, price: newPrice)).copyWith(
      price: newPrice,
      updatedAt: DateTime.utc(2026, 11, 10, 12),
    );
    if (idx >= 0) items[idx] = updated;
    return updated;
  }
}

class _FakeConnectivity implements ConnectivityRepository, NetworkTransportRepository {
  bool online = true;
  NetworkTransport transport = NetworkTransport.wifi;
  final onlineController = StreamController<bool>.broadcast();
  final transportController = StreamController<NetworkTransport>.broadcast();

  void setOnline(bool value, {NetworkTransport? nextTransport}) {
    online = value;
    transport = nextTransport ?? (value ? NetworkTransport.wifi : NetworkTransport.none);
    onlineController.add(online);
    transportController.add(transport);
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

class _NoSender implements OutboxSender {
  @override
  Future<String> uploadPhoto(String path) => throw UnimplementedError();
  @override
  Future<void> createListing(Map<String, dynamic> body) => throw UnimplementedError();
  @override
  Future<void> sendMessage(PendingMessage message) => throw UnimplementedError();
  @override
  Future<void> sendAction(PendingAction action) => throw UnimplementedError();
}

class _NoWishlist implements WishlistRepository {
  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() async => const CachedList([]);
  @override
  Future<WishlistItemEntity> add(String materialId) => throw UnimplementedError();
  @override
  Future<void> remove(String wishlistItemId) async {}
}

class _NoChats implements ChatRepository {
  @override
  Future<List<ChatRoomEntity>> getChatRooms() async => const [];
  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() async => const CachedList([]);
  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) => throw UnimplementedError();
  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) async => const [];
  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) async => const CachedList([]);
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
      createdAt: DateTime(2026, 11, 10, 10, _seq),
    );
    _messages.add(item);
    _emit();
    return item;
  }

  @override
  Future<List<PendingMessage>> messages(String ownerId, {String? chatRoomId}) async =>
      _messages.where((m) => m.ownerId == ownerId && (chatRoomId == null || m.chatRoomId == chatRoomId)).toList();

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
      createdAt: DateTime(2026, 11, 10, 10, _seq),
    );
    _listings.add(item);
    _emit();
    return item;
  }

  @override
  Future<void> saveUploadedUrls(String listingId, List<String> urls) async {}

  @override
  Future<List<String>> photoPathsOf(String listingId) async => const [];

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
      createdAt: DateTime(2026, 11, 10, 10, _seq),
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
  Future<void> markRetry(PendingKind kind, String id, String reason) async {}

  @override
  Future<void> markRefused(PendingKind kind, String id, String reason) async {}

  @override
  Future<void> retry(PendingKind kind, String id) async {}

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

  group('DeadListingsModel DTO', () {
    test('parses analytics JSON and preserves all fields across toJson/fromJson roundtrip', () {
      final parsed = DeadListingsModel.fromJson(_bq10Json(staleDays: 21));

      expect(parsed.summary.staleDays, 21);
      expect(parsed.hasData, isTrue);
      expect(parsed.summary.deadListings, 5);
      expect(parsed.survivalCurve.length, 5);
      expect(parsed.clusters.first.label, 'Overpriced Textbooks');
      expect(parsed.atRiskListings.length, 2);
      expect(parsed.sellerSummary?.deadListings, 1);

      final again = DeadListingsModel.fromJson(DeadListingsModel.toJson(parsed));
      expect(again.summary.staleDays, 21);
      expect(again.summary.deadShare, closeTo(0.42, 0.001));
      expect(again.clusters.last.clusterId, 'cluster-low-trust');
      expect(again.atRiskListings.first.suggestedPrice, 52200);
      expect(again.sellerSummary?.sellerId, 'ana-id');
    });
  });

  group('ListingHealthPreferencesRepositoryImpl (SharedPreferences)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists staleDays and dismissedIds per seller across restarts', () async {
      final repo1 = ListingHealthPreferencesRepositoryImpl();
      expect(await repo1.loadStaleDays('ana-id'), 14);
      expect(await repo1.loadDismissedIds('ana-id'), isEmpty);

      await repo1.saveStaleDays('ana-id', 21);
      await repo1.saveDismissedIds('ana-id', {'mat-2', 'mat-1'});
      await repo1.saveStaleDays('luis-id', 7);

      final repo2 = ListingHealthPreferencesRepositoryImpl();
      expect(await repo2.loadStaleDays('ana-id'), 21);
      expect(await repo2.loadStaleDays('luis-id'), 7);
      expect(await repo2.loadDismissedIds('ana-id'), {'mat-1', 'mat-2'});
    });
  });

  group('ListingHealthRepositoryImpl (ResponseCache RAM LRU + SQLite)', () {
    late AppDatabase db;
    late bool offline;

    ListingHealthRepositoryImpl buildRepo() => ListingHealthRepositoryImpl(
          remote: AnalyticsRemoteDataSource(
            apiClient: ApiClient(
              baseUrl: 'https://analytics.test',
              client: MockClient((request) async {
                expect(request.url.path, '/analytics/dead-listings/');
                if (offline) throw http.ClientException('offline');
                final days = int.tryParse(request.url.queryParameters['staleDays'] ?? '14') ?? 14;
                return http.Response(jsonEncode(_bq10Json(staleDays: days)), 200);
              }),
            ),
          ),
          cache: ResponseCache(db),
        );

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      offline = false;
    });

    tearDown(() => db.close());

    test('caches online answer by sellerId + staleDays and serves SQLite fallback with savedAt offline', () async {
      final onlineRepo = buildRepo();
      final fresh = await onlineRepo.getDeadListings(staleDays: 14, sellerId: 'ana-id');
      expect(fresh.fromCache, isFalse);
      expect(fresh.data.clusters.length, 2);

      // Simulate restart with fresh in-memory cache instance sharing the same SQLite DB.
      offline = true;
      final restartedRepo = buildRepo();
      final cached = await restartedRepo.getDeadListings(staleDays: 14, sellerId: 'ana-id');
      expect(cached.fromCache, isTrue);
      expect(cached.savedAt, isNotNull);
      expect(cached.data.atRiskListings.first.title, 'Linear Algebra 5th Ed');

      // Different staleDays key that was never cached offline fails cleanly.
      expect(
        restartedRepo.getDeadListings(staleDays: 30, sellerId: 'ana-id'),
        throwsA(isA<NoConnectionException>()),
      );
    });
  });

  group('Worker Isolates (listing_health_analyzer)', () {
    test('parseDeadListingsInBackground decodes JSON payload in Isolate.run', () async {
      final model = await parseDeadListingsInBackground(_bq10Json(staleDays: 7));
      expect(model.summary.staleDays, 7);
      expect(model.clusters.length, 2);
    });

    test('analyzeSellerListingHealth applies local price overrides, partitions dismissed items, and falls back offline',
        () async {
      final report = DeadListingsModel.fromJson(_bq10Json());
      final sellerItems = [
        _material('00000000-0000-4000-8000-00000000d001', price: 90000),
        _material('00000000-0000-4000-8000-00000000d002', title: 'Casio fx-991EX', price: 65000, category: MaterialCategoryEnum.CALCULATORS),
        _material(
          'mat-local-only',
          title: 'Lab Coat',
          price: 120000,
          category: MaterialCategoryEnum.LAB_EQUIPMENT,
          imageUrls: const [],
          createdAt: DateTime.utc(2026, 9, 15),
        ),
      ];

      final res = await analyzeSellerListingHealth(
        report: report,
        sellerListings: sellerItems,
        allMarketplaceListings: [
          ...sellerItems,
          _material('m-ref', price: 60000, sellerId: 'other', category: MaterialCategoryEnum.LAB_EQUIPMENT),
        ],
        sellerId: 'ana-id',
        staleDays: 14,
        dismissedIds: {'00000000-0000-4000-8000-00000000d002'},
        localPriceOverrides: {'00000000-0000-4000-8000-00000000d001': 55000},
        now: DateTime.utc(2026, 11, 10),
      );

      expect(res.usedLocalFallback, isFalse);
      expect(res.elapsedMicroseconds, greaterThanOrEqualTo(0));
      expect(res.dismissedAdvisories.map((i) => i.id), ['00000000-0000-4000-8000-00000000d002']);
      final updatedBook = res.activeAdvisories.firstWhere((i) => i.id == '00000000-0000-4000-8000-00000000d001');
      expect(updatedBook.price, 55000);
      expect(updatedBook.riskScore, lessThan(82));
      expect(res.activeAdvisories.any((i) => i.id == 'mat-local-only'), isTrue);

      // Cold-start offline fallback when BQ 10 has no cached data yet.
      final fallback = await analyzeSellerListingHealth(
        report: DeadListingsInsight.empty,
        sellerListings: sellerItems,
        allMarketplaceListings: sellerItems,
        sellerId: 'ana-id',
        staleDays: 14,
        dismissedIds: const {},
        now: DateTime.utc(2026, 11, 10),
      );
      expect(fallback.usedLocalFallback, isTrue);
      expect(fallback.activeAdvisories.length, 3);
    });

    test('simulatePriceDropInIsolate computes lower projected risk and sell days', () async {
      final item = DeadListingsModel.fromJson(_bq10Json()).atRiskListings.first;
      final sim = await simulatePriceDropInIsolate(
        item: item,
        newPrice: 52000,
        staleDays: 14,
        baselineCategorySellDays: 12.0,
      );

      expect(sim.projectedRiskScore, lessThan(sim.currentRiskScore));
      expect(sim.dropPercent, closeTo(42.2, 0.2));
      expect(sim.estimatedSellDays, isNotNull);
    });
  });

  group('Eventual Connectivity: Outbox Price Drop Delivery', () {
    late AppDatabase db;
    late OutboxStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.withFactory(databaseFactoryFfi);
      store = OutboxStore(db);
    });

    tearDown(() => db.close());

    test('PendingActionKind.updateListingPrice sends PATCH /materials/:id with formatted decimal price on reconnect',
        () async {
      final patchedBodies = <Map<String, dynamic>>[];
      var allowServer = false;

      final api = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((req) async {
          if (!allowServer) throw http.ClientException('offline');
          if (req.method == 'PATCH' && req.url.path == '/materials/00000000-0000-4000-8000-00000000d001') {
            final decoded = jsonDecode(req.body) as Map<String, dynamic>;
            patchedBodies.add(decoded);
            return http.Response(jsonEncode(_materialPayload('00000000-0000-4000-8000-00000000d001', price: 52200)), 200);
          }
          return http.Response('{}', 404);
        }),
      );
      final remote = MarketplaceRemoteDataSourceImpl(apiClient: api);
      final meetups = MeetupRemoteDataSourceImpl(apiClient: api);
      final net = _FakeConnectivity()..online = false;

      final sync = OutboxSyncService(
        store: store,
        sender: RemoteOutboxSender(remote, meetups),
        transport: net,
        mobileDataPreference: MobileDataPreferenceRepositoryImpl(),
        connectivity: net,
      );
      sync.start('ana-id');

      final actionRepo = PendingActionRepositoryImpl(store, sync: sync);
      await QueuePriceUpdateUseCase(actionRepo).execute(
        ownerId: 'ana-id',
        materialId: '00000000-0000-4000-8000-00000000d001',
        newPrice: 52200,
        listingTitle: 'Linear Algebra 5th Ed',
      );
      expect(await store.actions('ana-id'), hasLength(1));

      allowServer = true;
      net.setOnline(true);
      await sync.flush();

      expect(patchedBodies, hasLength(1));
      expect(patchedBodies.single['price'], '52200.00');
      expect(await store.actions('ana-id'), isEmpty);
      sync.dispose();
    });
  });

  group('ListingHealthViewModel', () {
    late AppDatabase db;
    late OutboxStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.withFactory(databaseFactoryFfi);
      store = OutboxStore(db);
    });

    tearDown(() => db.close());

    test('online price drop updates listing immediately; offline queues PendingAction and persists dismiss', () async {
      final healthRepo = _FakeListingHealthRepo();
      final matRepo = _FakeMaterialRepo([_material('00000000-0000-4000-8000-00000000d001', price: 90000)]);
      final prefsRepo = ListingHealthPreferencesRepositoryImpl();
      final pendingRepo = PendingActionRepositoryImpl(store);

      final syncedEntities = <MaterialEntity>[];
      final vm = ListingHealthViewModel(
        userId: 'ana-id',
        getInsight: GetDeadListingsInsightUseCase(healthRepo),
        loadPreferences: LoadListingHealthPreferencesUseCase(prefsRepo),
        saveStaleDays: SaveListingHealthStaleDaysUseCase(prefsRepo),
        saveDismissedIds: SaveDismissedHealthAlertsUseCase(prefsRepo),
        updateListingPrice: UpdateListingPriceUseCase(matRepo),
        queuePriceUpdate: QueuePriceUpdateUseCase(pendingRepo),
        watchPendingActions: WatchPendingActionsUseCase(pendingRepo),
        discardPendingAction: DiscardPendingActionUseCase(pendingRepo),
        getMarketplaceListings: () => matRepo.items,
        onMaterialUpdated: syncedEntities.add,
      );

      await vm.initialize();
      expect(vm.activeAdvisories.length, 2);

      // Dismiss one advisory and verify persistence + toggle.
      await vm.toggleDismissAlert('00000000-0000-4000-8000-00000000d002');
      expect(vm.activeAdvisories.length, 1);
      expect(vm.dismissedAdvisories.length, 1);
      expect(await prefsRepo.loadDismissedIds('ana-id'), {'00000000-0000-4000-8000-00000000d002'});

      // Online price drop.
      final onlineItem = vm.activeAdvisories.first;
      await vm.applyPriceDrop(onlineItem, 52200);
      expect(matRepo.updates, [('00000000-0000-4000-8000-00000000d001', 52200.0)]);
      expect(syncedEntities.last.price, 52200);
      expect(vm.activeAdvisories.first.price, 52200);

      // Offline price drop falls back to OutboxStore queue + optimistic UI update.
      matRepo.updateError = const NoConnectionException();
      await vm.applyPriceDrop(vm.activeAdvisories.first, 48000);
      final queued = await store.actions('ana-id');
      expect(queued, hasLength(1));
      expect(queued.single.kind, PendingActionKind.updateListingPrice);
      expect(vm.isPriceQueued('00000000-0000-4000-8000-00000000d001'), isTrue);
      expect(vm.activeAdvisories.first.price, 48000);
      expect(vm.statusMessage, contains('Saved offline'));

      // Changing staleDays persists preference and refreshes report.
      await vm.changeStaleDays(30);
      expect(vm.staleDays, 30);
      expect(await prefsRepo.loadStaleDays('ana-id'), 30);
      expect(healthRepo.lastStaleDays, 30);

      vm.dispose();
    });
  });

  group('ListingHealthScreen & SellerHubScreen Navigation Widgets', () {
    late _MemoryOutboxStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _MemoryOutboxStore();
    });

    tearDown(() => store.dispose());

    Future<(AppViewModel, _FakeConnectivity, _FakeMaterialRepo)> buildAppState() async {
      final net = _FakeConnectivity();
      final matRepo = _FakeMaterialRepo([_material('00000000-0000-4000-8000-00000000d001', price: 90000)]);
      final dummySync = OutboxSyncService(
        store: store,
        sender: _NoSender(),
        connectivity: net,
      );
      final appState = AppViewModel(
        marketplace: MarketplaceViewModel(
          getMaterials: GetMaterialsUseCase(matRepo),
          createListing: CreateListingUseCase(matRepo),
          getWishlist: GetWishlistUseCase(_NoWishlist()),
          addToWishlist: AddToWishlistUseCase(_NoWishlist()),
          removeFromWishlist: RemoveFromWishlistUseCase(_NoWishlist()),
        ),
        chats: ChatViewModel(
          getChatRooms: GetChatRoomsUseCase(_NoChats()),
          openChatRoom: OpenChatRoomUseCase(_NoChats()),
          getMessages: GetMessagesUseCase(_NoChats()),
          sendMessage: SendMessageUseCase(_NoChats()),
          markRead: MarkChatReadUseCase(_NoChats()),
          answerProposal: AnswerMeetingProposalUseCase(_NoMeetups()),
          getConversationInsight: GetConversationInsightUseCase(_NoInsights()),
          queueMessage: QueueMessageUseCase(store, dummySync),
          retryPendingMessage: RetryPendingMessageUseCase(store, dummySync),
          deletePendingMessage: DeletePendingMessageUseCase(store, dummySync),
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
        meetups: MeetupUseCases(
          getMeetingPoints: GetMeetingPointsUseCase(_NoMeetups()),
          getSuggestions: GetMeetingSuggestionsUseCase(_NoMeetups()),
          propose: ProposeMeetingUseCase(_NoMeetups()),
          answer: AnswerMeetingProposalUseCase(_NoMeetups()),
          currentLocation: GetCurrentLocationUseCase(_NoLocation()),
          rankZones: RankSafeZonesUseCase(),
          recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
          getDensity: GetMeetingPointDensityUseCase(_NoDensity()),
        ),
        theme: ThemeViewModel(
          watchAmbientLight: WatchAmbientLightUseCase(_NoLight()),
          loadPreference: LoadThemePreferenceUseCase(_NoThemePrefs()),
          savePreference: SaveThemePreferenceUseCase(_NoThemePrefs()),
        ),
        power: PowerViewModel(watchBattery: WatchBatteryUseCase(_NoBattery())),
        connectivity: ConnectivityViewModel(
          getConnectivity: GetConnectivityUseCase(net),
          watchConnectivity: WatchConnectivityUseCase(net),
        ),
        trackEvent: TrackEventUseCase(_NoTracker()),
      );
      addTearDown(() async {
        dummySync.dispose();
        await net.onlineController.close();
        await net.transportController.close();
      });
      appState.connectivity.start();
      appState.login(UserEntity(
        id: 'ana-id',
        email: 'ana@uniandes.edu.co',
        fullName: 'Ana Gomez',
        major: 'ISIS',
        rating: 4.6,
        createdAt: DateTime(2026, 9, 1),
      ));
      await appState.marketplace.load();
      return (appState, net, matRepo);
    }

    testWidgets('SellerHubScreen navigates to AppScreen.listingHealth when tapping Advisor card', (tester) async {
      final (appState, _, _) = await buildAppState();
      addTearDown(appState.dispose);

      await tester.pumpWidget(MaterialApp(home: SellerHubScreen(appState: appState)));
      await tester.pumpAndSettle();

      final entry = find.byKey(const Key('open-listing-health-advisor'));
      expect(entry, findsOneWidget);
      await tester.tap(entry);
      await tester.pump();

      expect(appState.currentScreen, AppScreen.listingHealth);
    });

    testWidgets('ListingHealthScreen shows cached banner offline, What-If simulator, and queued badge',
        (tester) async {
      final (appState, net, matRepo) = await buildAppState();
      addTearDown(appState.dispose);

      net.setOnline(false);
      matRepo.updateError = const NoConnectionException();
      final healthRepo = _FakeListingHealthRepo()
        ..nextResult = CachedResult.saved(
          DeadListingsModel.fromJson(_bq10Json()),
          DateTime.now().subtract(const Duration(minutes: 15)),
        );
      final prefsRepo = ListingHealthPreferencesRepositoryImpl();
      final pendingRepo = PendingActionRepositoryImpl(store);
      late ListingHealthViewModel vm;

      Future<void> settleWithIsolates(bool Function() ready) async {
        for (var i = 0; i < 60 && !ready(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ListingHealthScreen(
            appState: appState,
            createViewModel: () {
              vm = ListingHealthViewModel(
                userId: 'ana-id',
                getInsight: GetDeadListingsInsightUseCase(healthRepo),
                loadPreferences: LoadListingHealthPreferencesUseCase(prefsRepo),
                saveStaleDays: SaveListingHealthStaleDaysUseCase(prefsRepo),
                saveDismissedIds: SaveDismissedHealthAlertsUseCase(prefsRepo),
                updateListingPrice: UpdateListingPriceUseCase(matRepo),
                queuePriceUpdate: QueuePriceUpdateUseCase(pendingRepo),
                watchPendingActions: WatchPendingActionsUseCase(pendingRepo),
                discardPendingAction: DiscardPendingActionUseCase(pendingRepo),
                getMarketplaceListings: () => appState.marketplace.materials,
                onMaterialUpdated: appState.marketplace.replaceMaterial,
              );
              return vm;
            },
          ),
        ),
      );
      await settleWithIsolates(() => !vm.isLoading && !vm.isAnalyzing);

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('Overpriced Textbooks'), findsOneWidget);

      final mainScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Linear Algebra 5th Ed'), 250, scrollable: mainScrollable);
      expect(find.text('Linear Algebra 5th Ed'), findsOneWidget);

      Future<void> scrollAndTap(Finder target) async {
        await tester.scrollUntilVisible(target, 200, scrollable: mainScrollable);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
      }

      // Open What-If simulator powered by Isolate.run.
      await scrollAndTap(find.byKey(const Key('simulate-btn-00000000-0000-4000-8000-00000000d001')));
      await settleWithIsolates(() => vm.simulation != null && !vm.isSimulating);
      expect(find.byKey(const Key('simulator-panel-00000000-0000-4000-8000-00000000d001')), findsOneWidget);

      // Queue an offline price drop and verify the pending badge appears.
      await scrollAndTap(find.byKey(const Key('apply-simulated-00000000-0000-4000-8000-00000000d001')));
      await settleWithIsolates(() => vm.isPriceQueued('00000000-0000-4000-8000-00000000d001') && !vm.isUpdating('00000000-0000-4000-8000-00000000d001'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('pending-price-00000000-0000-4000-8000-00000000d001')),
        -150,
        scrollable: mainScrollable,
      );
      await tester.ensureVisible(find.byKey(const Key('pending-price-00000000-0000-4000-8000-00000000d001')));
      expect(find.byKey(const Key('pending-price-00000000-0000-4000-8000-00000000d001')), findsOneWidget);
      final queued = await store.actions('ana-id');
      expect(queued, hasLength(1));
    });
  });
}
