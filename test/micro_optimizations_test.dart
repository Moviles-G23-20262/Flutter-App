import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/app/theme/app_theme.dart';
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
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/model/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/model/repositories/pending_listing_repository.dart';
import 'package:flutter_front_end/model/repositories/power_repositories.dart';
import 'package:flutter_front_end/model/use_cases/appearance_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/model/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/model/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_listing_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/power_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/view/screens/chat_view.dart';
import 'package:flutter_front_end/view/screens/home_screen.dart';
import 'package:flutter_front_end/view/screens/search_screen.dart';
import 'package:flutter_front_end/view/widgets/cached_photo.dart';
import 'package:flutter_front_end/view/widgets/common_widgets.dart';
import 'package:flutter_front_end/view/widgets/formatters.dart';
import 'package:flutter_front_end/view_model/account_view_model.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/chat_view_model.dart';
import 'package:flutter_front_end/view_model/connectivity_view_model.dart';
import 'package:flutter_front_end/view_model/marketplace_view_model.dart';
import 'package:flutter_front_end/view_model/power_view_model.dart';
import 'package:flutter_front_end/view_model/schedule_view_model.dart';
import 'package:flutter_front_end/view_model/theme_view_model.dart';

const _me = '3f2b8c1e-0000-4000-8000-000000000001';
const _other = '3f2b8c1e-0000-4000-8000-000000000002';

class _MemMaterials implements MaterialRepository {
  List<MaterialEntity> materials = [];

  @override
  Future<List<MaterialEntity>> getMaterials() async => materials;

  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() async => CachedList(materials);

  @override
  Future<MaterialEntity> createListing(NewListingData data) async => MaterialEntity(
        id: 'created-1',
        title: data.title,
        description: data.description,
        price: data.price,
        status: MaterialStatusEnum.AVAILABLE,
        condition: data.condition,
        imageUrls: const [],
        sellerId: _me,
        category: data.category,
        createdAt: DateTime(2026, 9, 4),
        updatedAt: DateTime(2026, 9, 4),
      );

  @override
  Future<MaterialEntity> updatePrice(String materialId, double newPrice) => throw UnimplementedError();
}

class _MemWishlist implements WishlistRepository {
  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() async => const CachedList([]);

  @override
  Future<WishlistItemEntity> add(String materialId) async => WishlistItemEntity(
        id: 'w-$materialId',
        userId: _me,
        materialId: materialId,
        createdAt: DateTime(2026, 9, 2),
      );

  @override
  Future<void> remove(String wishlistItemId) async {}
}

class _MemChats implements ChatRepository {
  List<ChatRoomEntity> rooms = [];
  List<MessageEntity> messages = [];

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async => rooms;

  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() async => CachedList(rooms);

  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) async => rooms.first;

  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) async => messages;

  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) async => CachedList(messages);

  @override
  Future<MessageEntity> sendMessage(String chatRoomId, String content, {String? id, DateTime? clientCreatedAt}) async =>
      MessageEntity(
        id: id ?? 'sent',
        chatRoomId: chatRoomId,
        senderId: _me,
        content: content,
        isRead: false,
        createdAt: clientCreatedAt ?? DateTime(2026, 9, 3),
      );

  @override
  Future<void> markRead(String chatRoomId) async {}
}

class _MemExchanges implements ExchangeRepository {
  @override
  Future<List<ExchangeEntity>> getExchanges() async => [];

  @override
  Future<ExchangeEntity> placeOrder(String materialId) => throw UnimplementedError();

  @override
  Future<ExchangeEntity> complete(String exchangeId, {MaterialConditionEnum? receivedCondition}) =>
      throw UnimplementedError();

  @override
  Future<ExchangeEntity> cancel(String exchangeId) => throw UnimplementedError();

  @override
  Future<void> rate(NewRating rating) async {}
}

class _MemMeetups implements MeetupRepository {
  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async => [];

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async =>
      const MeetingSuggestions(slots: [], callerHasSchedule: true, otherHasSchedule: true);

  @override
  Future<MeetingProposalEntity> propose({
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> accept(String proposalId) => throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> decline(String proposalId) => throw UnimplementedError();

  @override
  Future<MeetingProposalEntity> withdraw(String proposalId) => throw UnimplementedError();
}

class _MemSchedule implements ScheduleRepository {
  @override
  Future<List<ScheduleBlockEntity>> getSchedule() async => [];

  @override
  Future<ScheduleBlockEntity> add(NewScheduleBlock block) => throw UnimplementedError();

  @override
  Future<void> remove(String blockId) async {}
}

class _MemLocation implements LocationRepository {
  @override
  Future<GeoPoint?> currentLocation() async => null;
}

class _MemDensity implements MeetingDensityRepository {
  @override
  Future<MeetingPointDensity> getDensity() async => MeetingPointDensity.empty;
}

class _MemPendingListings implements PendingListingRepository {
  final _ctrl = StreamController<List<PendingListing>>.broadcast();

  @override
  Stream<List<PendingListing>> watch(String ownerId) => _ctrl.stream;

  @override
  Future<void> retry(String listingId) async {}

  @override
  Future<void> discard(String listingId) async {}

  @override
  Future<PendingListing> queue({
    required String ownerId,
    required NewListingData data,
    required List<String> photoPaths,
  }) =>
      throw UnimplementedError();
}

class _MemInsights implements ConversationInsightRepository {
  @override
  Future<ConversationInsight> getConversationInsight() async =>
      const ConversationInsight(conversationsAnalyzed: 0, medianMessages: 0, medianMinutes: 0);

  @override
  Future<ChatAgreement> getChatAgreement(String chatRoomId) async =>
      throw const ApiException(404, 'Not found');
}

class _MemNotifications implements NotificationRepository {
  List<NotificationEntity> items = [];

  @override
  Future<CachedList<NotificationEntity>> getNotifications() async => CachedList(items);

  @override
  Future<void> markOpened(String notificationId) async {}
}

class _MemTracker implements AnalyticsEventRepository {
  @override
  Future<void> track(AnalyticsEvent event) async {}
}

class _MemNetwork implements ConnectivityRepository {
  bool online = true;
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => controller.stream;
}

class _MemBattery implements BatteryRepository {
  final controller = StreamController<PowerStatus>.broadcast();

  @override
  Stream<PowerStatus> watch() => controller.stream;
}

class _MemLight implements AmbientLightRepository {
  @override
  Stream<double> luxReadings() => const Stream.empty();
}

class _MemThemePrefs implements ThemePreferenceRepository {
  @override
  Future<ThemePreference?> load() async => null;

  @override
  Future<void> save(ThemePreference preference) async {}
}

class _World {
  final materials = _MemMaterials();
  final wishlist = _MemWishlist();
  final chats = _MemChats();
  final exchanges = _MemExchanges();
  final notifications = _MemNotifications();
  final meetupsRepo = _MemMeetups();
  final scheduleRepo = _MemSchedule();
  final location = _MemLocation();
  final density = _MemDensity();
  final insights = _MemInsights();
  final pendingListings = _MemPendingListings();
  final battery = _MemBattery();
  final network = _MemNetwork();
  final tracker = _MemTracker();

  late final meetups = MeetupUseCases(
    getMeetingPoints: GetMeetingPointsUseCase(meetupsRepo),
    getSuggestions: GetMeetingSuggestionsUseCase(meetupsRepo),
    propose: ProposeMeetingUseCase(meetupsRepo),
    answer: AnswerMeetingProposalUseCase(meetupsRepo),
    currentLocation: GetCurrentLocationUseCase(location),
    rankZones: RankSafeZonesUseCase(),
    recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
    getDensity: GetMeetingPointDensityUseCase(density),
  );

  late final marketplaceState = MarketplaceViewModel(
    getMaterials: GetMaterialsUseCase(materials),
    createListing: CreateListingUseCase(materials),
    getWishlist: GetWishlistUseCase(wishlist),
    addToWishlist: AddToWishlistUseCase(wishlist),
    removeFromWishlist: RemoveFromWishlistUseCase(wishlist),
    watchPendingListings: WatchPendingListingsUseCase(pendingListings),
    discardPendingListing: DiscardPendingListingUseCase(pendingListings),
  );

  late final chatState = ChatViewModel(
    getChatRooms: GetChatRoomsUseCase(chats),
    openChatRoom: OpenChatRoomUseCase(chats),
    getMessages: GetMessagesUseCase(chats),
    sendMessage: SendMessageUseCase(chats),
    markRead: MarkChatReadUseCase(chats),
    answerProposal: meetups.answer,
    getConversationInsight: GetConversationInsightUseCase(insights),
    getChatAgreement: GetChatAgreementUseCase(insights),
    trackEvent: TrackEventUseCase(tracker),
  );

  late final accountState = AccountViewModel(
    getExchanges: GetExchangesUseCase(exchanges),
    getNotifications: GetNotificationsUseCase(notifications),
    markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
    placeOrder: PlaceOrderUseCase(exchanges),
    completeExchange: CompleteExchangeUseCase(exchanges),
    cancelExchange: CancelExchangeUseCase(exchanges),
    rateUser: RateUserUseCase(exchanges),
  );

  late final scheduleState = ScheduleViewModel(
    getSchedule: GetScheduleUseCase(scheduleRepo),
    addBlock: AddScheduleBlockUseCase(scheduleRepo),
    removeBlock: RemoveScheduleBlockUseCase(scheduleRepo),
  );

  late final appState = AppViewModel(
    marketplace: marketplaceState,
    chats: chatState,
    account: accountState,
    schedule: scheduleState,
    meetups: meetups,
    theme: ThemeViewModel(
      watchAmbientLight: WatchAmbientLightUseCase(_MemLight()),
      loadPreference: LoadThemePreferenceUseCase(_MemThemePrefs()),
      savePreference: SaveThemePreferenceUseCase(_MemThemePrefs()),
    ),
    power: PowerViewModel(watchBattery: WatchBatteryUseCase(battery)),
    trackEvent: TrackEventUseCase(tracker),
    connectivity: ConnectivityViewModel(
      getConnectivity: GetConnectivityUseCase(network),
      watchConnectivity: WatchConnectivityUseCase(network),
    ),
  );

  bool _cleaned = false;

  Future<void> cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    chatState.clear();
    appState.dispose();
    await pendingListings._ctrl.close();
    await battery.controller.close();
    await network.controller.close();
  }
}

List<MaterialEntity> _sampleMaterials(int count) {
  const cats = MaterialCategoryEnum.values;
  const conds = MaterialConditionEnum.values;
  return List.generate(count, (i) {
    final sellerIdx = i % 6;
    return MaterialEntity(
      id: 'mat-$i',
      title: i % 2 == 0 ? 'Calc $i' : 'Book $i',
      description: 'Desc $i',
      courseCode: i % 2 == 0 ? 'ISIS 3510' : 'MATH 1202',
      price: 25000.0 + i * 2000.0,
      condition: conds[i % conds.length],
      status: i % 10 == 0 ? MaterialStatusEnum.SOLD : MaterialStatusEnum.AVAILABLE,
      imageUrls: const [],
      sellerId: 'seller-$sellerIdx',
      seller: UserSummary(id: 'seller-$sellerIdx', fullName: 'Seller $sellerIdx', major: 'ISIS', rating: 4.0 + (sellerIdx % 5) * 0.2),
      category: cats[i % cats.length],
      createdAt: DateTime(2026, 9, 1).add(Duration(hours: i)),
      updatedAt: DateTime(2026, 9, 1).add(Duration(hours: i)),
    );
  });
}

void main() {
  test('AppTheme & AppDecorations reuse static immutable instances', () {
    expect(identical(AppTheme.lightTheme, AppTheme.lightTheme), isTrue);
    expect(identical(AppTheme.darkTheme, AppTheme.darkTheme), isTrue);

    for (final b in Brightness.values) {
      expect(identical(AppDecorations.heroGradient(b), AppDecorations.heroGradient(b)), isTrue);
      expect(identical(AppDecorations.card(b), AppDecorations.card(b)), isTrue);
      expect(identical(AppDecorations.productCard(b), AppDecorations.productCard(b)), isTrue);
      expect(identical(AppDecorations.elevated(b), AppDecorations.elevated(b)), isTrue);
      expect(identical(AppDecorations.accentShadow(b), AppDecorations.accentShadow(b)), isTrue);
      expect(identical(AppDecorations.badge(b, highlighted: false), AppDecorations.badge(b, highlighted: false)), isTrue);
      expect(identical(AppDecorations.badge(b, highlighted: true), AppDecorations.badge(b, highlighted: true)), isTrue);
      expect(identical(AppDecorations.pill(b, active: false), AppDecorations.pill(b, active: false)), isTrue);
      expect(identical(AppDecorations.pill(b, active: true), AppDecorations.pill(b, active: true)), isTrue);
    }
  });

  test('isSameLocalDay and chatDayLabel handle day boundaries cleanly', () {
    final morning = DateTime(2026, 9, 14, 8, 15);
    final night = DateTime(2026, 9, 14, 23, 59);
    final nextDay = DateTime(2026, 9, 15, 0, 1);

    expect(isSameLocalDay(morning, night), isTrue);
    expect(isSameLocalDay(night, nextDay), isFalse);

    final now = DateTime.now();
    expect(chatDayLabel(DateTime(now.year, now.month, now.day, 14, 30), now: now), 'Today');
    expect(
      chatDayLabel(DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 3)), now: now),
      'Yesterday',
    );
  });

  testWidgets('AppCard reuses cached decoration unless borderRadius is customized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              const AppCard(key: Key('default-card'), child: Text('A')),
              AppCard(key: const Key('custom-card'), borderRadius: BorderRadius.circular(24), child: const Text('B')),
            ],
          ),
        ),
      ),
    );

    final defaultContainer = tester.widget<Container>(
      find.descendant(of: find.byKey(const Key('default-card')), matching: find.byType(Container)),
    );
    final customContainer = tester.widget<Container>(
      find.descendant(of: find.byKey(const Key('custom-card')), matching: find.byType(Container)),
    );

    expect(identical(defaultContainer.decoration, AppDecorations.card(Brightness.light)), isTrue);
    expect((customContainer.decoration as BoxDecoration).borderRadius, BorderRadius.circular(24));
  });

  test('MarketplaceViewModel caches availableMaterials and invalidates on writes', () async {
    final world = _World();
    addTearDown(world.cleanup);
    world.materials.materials = _sampleMaterials(10);

    await world.marketplaceState.load();
    final read1 = world.marketplaceState.availableMaterials;
    final read2 = world.marketplaceState.availableMaterials;
    expect(identical(read1, read2), isTrue);
    expect(read1.length, 9);

    await world.marketplaceState.publish(
      NewListingData(
        title: 'Linear Algebra',
        description: 'Clean copy',
        price: 45000,
        condition: MaterialConditionEnum.GOOD,
        category: MaterialCategoryEnum.BOOKS,
      ),
    );
    final afterPublish = world.marketplaceState.availableMaterials;
    expect(identical(read1, afterPublish), isFalse);
    expect(afterPublish.length, 10);

    world.marketplaceState.replaceMaterial(afterPublish.first.copyWith(price: 38000));
    final afterReplace = world.marketplaceState.availableMaterials;
    expect(identical(afterPublish, afterReplace), isFalse);
    expect(afterReplace.first.price, 38000);

    world.marketplaceState.clear();
    expect(world.marketplaceState.availableMaterials, isEmpty);
  });

  testWidgets('CachedPhoto scales decode bounds cleanly, omits redundant ClipRRect, and fits 8 2000x1500 photos inside 50 MB cache', (tester) async {
    final cacheTmpDir = Directory.systemTemp.createTempSync('campus_swap_micro_cache_');
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => cacheTmpDir.path,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProviderChannel, null);
      if (cacheTmpDir.existsSync()) cacheTmpDir.deleteSync(recursive: true);
    });

    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages()
      ..maximumSize = 100
      ..maximumSizeBytes = 50 * 1024 * 1024;
    addTearDown(() => PaintingBinding.instance.imageCache..clear()..clearLiveImages());

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(412, 915), devicePixelRatio: 2.0),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(
                  key: Key('photo-card'),
                  width: 155,
                  height: 110,
                  child: CachedPhoto(imageUrl: 'https://cdn.example.com/a.jpg', width: 155, height: 110),
                ),
                const SizedBox(
                  key: Key('photo-grid'),
                  width: 185,
                  height: 120,
                  child: CachedPhoto(imageUrl: 'https://cdn.example.com/b.jpg'),
                ),
                CachedPhoto(
                  key: const Key('photo-rounded'),
                  imageUrl: 'https://cdn.example.com/c.jpg',
                  width: 68,
                  height: 68,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final cnCard = tester.widget<CachedNetworkImage>(
      find.descendant(of: find.byKey(const Key('photo-card')), matching: find.byType(CachedNetworkImage)),
    );
    final cnGrid = tester.widget<CachedNetworkImage>(
      find.descendant(of: find.byKey(const Key('photo-grid')), matching: find.byType(CachedNetworkImage)),
    );
    final cnRounded = tester.widget<CachedNetworkImage>(
      find.descendant(of: find.byKey(const Key('photo-rounded')), matching: find.byType(CachedNetworkImage)),
    );

    // Exactly one decode bound is set so aspect ratio is preserved while shrinking decoded RGBA bytes.
    expect(cnCard.memCacheWidth, 310);
    expect(cnCard.memCacheHeight, isNull);
    expect(cnGrid.memCacheWidth, 370);
    expect(cnGrid.memCacheHeight, isNull);
    expect(cnRounded.memCacheWidth, anyOf(136, isNull));

    // Only the photo with a non-zero borderRadius introduces a ClipRRect node.
    expect(find.byType(ClipRRect), findsOneWidget);

    // Decode 8 distinct 2000x1500 PNGs using the card bound (310 px wide).
    final rgb = Uint8List(2000 * 1500 * 3);
    final pngs = <Uint8List>[
      for (var i = 0; i < 8; i++)
        Uint8List.fromList(
          img.encodePng(
            img.Image.fromBytes(
              width: 2000,
              height: 1500,
              bytes: (rgb..[0] = (i * 31) & 0xFF).buffer,
              numChannels: 3,
            ),
            level: 0,
          ),
        ),
    ];

    await tester.runAsync(() async {
      for (var i = 0; i < 8; i++) {
        final provider = ResizeImage.resizeIfNeeded(cnCard.memCacheWidth, cnCard.memCacheHeight, MemoryImage(pngs[i]));
        final stream = provider.resolve(ImageConfiguration.empty);
        final done = Completer<ImageInfo>();
        late final ImageStreamListener listener;
        listener = ImageStreamListener((info, _) {
          if (!done.isCompleted) done.complete(info);
        });
        stream.addListener(listener);
        await done.future;
        stream.removeListener(listener);
      }
    });

    final cache = PaintingBinding.instance.imageCache;
    expect(cache.currentSize, 8);
    expect(cache.currentSizeBytes, lessThan(3 * 1024 * 1024));
  });

  testWidgets('ChatView isolates composer typing from timeline bubbles and listing strip', (tester) async {
    final world = _World();
    addTearDown(world.cleanup);

    final room = ChatRoomEntity(
      id: 'r-1',
      materialId: 'mat-1',
      buyerId: _me,
      sellerId: _other,
      createdAt: DateTime(2026, 9, 1, 9, 0),
      material: MaterialEntity(
        id: 'mat-1',
        title: 'Casio fx-991EX',
        description: 'Clean',
        price: 65000,
        status: MaterialStatusEnum.AVAILABLE,
        condition: MaterialConditionEnum.LIKE_NEW,
        imageUrls: const [],
        sellerId: _other,
        category: MaterialCategoryEnum.CALCULATORS,
        createdAt: DateTime(2026, 9, 1, 8, 0),
        updatedAt: DateTime(2026, 9, 1, 8, 0),
      ),
      buyer: const UserSummary(id: _me, fullName: 'Sabrina Noguera', major: 'ISIS', rating: 4.9),
      seller: const UserSummary(id: _other, fullName: 'Carlos Ruiz', major: 'MATE', rating: 4.7),
    );
    world.chats.rooms = [room];
    world.chats.messages = List.generate(
      40,
      (i) => MessageEntity(
        id: 'm-$i',
        chatRoomId: 'r-1',
        senderId: i.isEven ? _me : _other,
        content: 'Message $i',
        isRead: true,
        createdAt: DateTime(2026, 9, 1 + (i ~/ 20), 10, i % 20),
      ),
    );
    world.appState.login(
      UserEntity(id: _me, email: 's@uniandes.edu.co', fullName: 'Sabrina Noguera', major: 'ISIS', rating: 4.9, createdAt: DateTime(2026, 1, 1)),
    );
    world.appState.chats.openRoom('r-1');
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatView(appState: world.appState, room: room))),
    );
    await tester.pumpAndSettle();

    final counts = <String, int>{};
    final prevHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      counts[name] = (counts[name] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = prevHook);

    await tester.enterText(find.byType(TextField), 'Available today?');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(counts['ChatView'] ?? 0, 0);
    expect(counts['_ListingStrip'] ?? 0, 0);
    expect(counts['_Bubble'] ?? 0, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await world.cleanup();
  });

  testWidgets('HomeScreen isolates notification ticks from listing cards and SearchScreen ignores unrelated wishlist ticks', (tester) async {
    final homeWorld = _World();
    addTearDown(homeWorld.cleanup);
    homeWorld.materials.materials = _sampleMaterials(30);
    homeWorld.appState.login(
      UserEntity(id: _me, email: 's@uniandes.edu.co', fullName: 'Sabrina Noguera', major: 'ISIS', rating: 4.9, createdAt: DateTime(2026, 1, 1)),
    );
    await homeWorld.marketplaceState.load();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: HomeScreen(appState: homeWorld.appState))),
    );
    await tester.pumpAndSettle();

    final homeCounts = <String, int>{};
    final prevHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      homeCounts[name] = (homeCounts[name] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = prevHook);

    homeWorld.notifications.items = [
      NotificationEntity(id: 'n1', userId: _me, type: NotificationTypeEnum.OTHER, sentAt: DateTime(2026, 9, 5)),
    ];
    await homeWorld.accountState.load();
    await tester.pump();

    expect(homeCounts['_ProductCard'] ?? 0, 0);
    expect(homeCounts['_RecommendedRow'] ?? 0, 0);
    expect(find.text('1'), findsOneWidget);

    debugOnRebuildDirtyWidget = prevHook;

    // Now verify SearchScreen skips unrelated wishlist notifications and filters synchronously.
    final searchWorld = _World();
    addTearDown(searchWorld.cleanup);
    searchWorld.materials.materials = _sampleMaterials(30);
    searchWorld.appState.login(
      UserEntity(id: _me, email: 's@uniandes.edu.co', fullName: 'Sabrina Noguera', major: 'ISIS', rating: 4.9, createdAt: DateTime(2026, 1, 1)),
    );
    await searchWorld.marketplaceState.load();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchScreen(appState: searchWorld.appState))),
    );
    await tester.pumpAndSettle();

    final searchCounts = <String, int>{};
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      searchCounts[name] = (searchCounts[name] ?? 0) + 1;
    };

    await searchWorld.marketplaceState.toggleFavorite('mat-1');
    await tester.pump();

    expect(searchCounts['_SearchProductCard'] ?? 0, 0);

    debugOnRebuildDirtyWidget = prevHook;

    await tester.enterText(find.byType(TextField), 'Calc');
    await tester.pump();
    expect(find.textContaining('found'), findsOneWidget);
    expect(find.textContaining('Calc 2'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await homeWorld.cleanup();
    await searchWorld.cleanup();
  });
}
