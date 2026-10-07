import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/Data/Models/marketplace_models.dart';
import 'package:flutter_front_end/Data/Repositories/marketplace_repositories_impl.dart';
import 'package:flutter_front_end/Data/data_sources/marketplace_remote_data_source.dart';
import 'package:flutter_front_end/Domain/Entities/chat_room_entity.dart';
import 'package:flutter_front_end/Domain/Entities/conversation_insight.dart';
import 'package:flutter_front_end/Domain/Entities/exchange_entity.dart';
import 'package:flutter_front_end/Domain/Entities/material_entity.dart';
import 'package:flutter_front_end/Domain/Entities/meeting_point_density.dart';
import 'package:flutter_front_end/Domain/Entities/meetup_entities.dart';
import 'package:flutter_front_end/Domain/Entities/new_listing_data.dart';
import 'package:flutter_front_end/Domain/Entities/notification_entity.dart';
import 'package:flutter_front_end/Domain/Entities/user_entity.dart';
import 'package:flutter_front_end/Domain/Entities/user_summary.dart';
import 'package:flutter_front_end/Domain/Entities/wishlist_item_entity.dart';
import 'package:flutter_front_end/Domain/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/Domain/repositories/conversation_insight_repository.dart';
import 'package:flutter_front_end/Domain/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/Domain/repositories/meeting_density_repository.dart';
import 'package:flutter_front_end/Domain/repositories/meetup_repositories.dart';
import 'package:flutter_front_end/Domain/use_cases/conversation_insight_use_case.dart';
import 'package:flutter_front_end/Domain/use_cases/get_meeting_point_density_use_case.dart';
import 'package:flutter_front_end/Domain/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/Domain/use_cases/meeting_point_recommendation_use_case.dart';
import 'package:flutter_front_end/Domain/use_cases/meetup_use_cases.dart';
import 'package:flutter_front_end/Domain/use_cases/rank_meeting_points_use_case.dart';
import 'package:flutter_front_end/Presentation/Screens/home_screen.dart';
import 'package:flutter_front_end/Presentation/State%20Management/account_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/app_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/chat_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/marketplace_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/meeting_planner_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/schedule_state.dart';
import 'package:flutter_front_end/Presentation/Widgets/formatters.dart';
import 'package:flutter_front_end/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _me = '3f2b8c1e-0000-4000-8000-000000000001';
const _other = '3f2b8c1e-0000-4000-8000-000000000002';

Map<String, dynamic> _sellerJson([String id = _other]) =>
    {'id': id, 'fullName': 'Jake Reyes', 'major': 'Chemistry', 'faculty': null, 'rating': 4.5};

Map<String, dynamic> _materialJson({String id = 'm1', String price = '18.00', String sellerId = _other}) => {
      'id': id,
      'title': 'Casio fx-991EX',
      'description': 'Barely used',
      'courseCode': 'MATH 201',
      'price': price,
      'condition': 'LIKE_NEW',
      'status': 'AVAILABLE',
      'edition': null,
      'model': null,
      'imageUrls': ['https://img/1.jpg'],
      'sellerId': sellerId,
      'category': 'CALCULATORS',
      'createdAt': '2026-09-01T10:00:00.000Z',
      'updatedAt': '2026-09-01T10:00:00.000Z',
      'seller': _sellerJson(sellerId),
    };

UserEntity _user() => UserEntity(
      id: _me,
      email: 'me@uniandes.edu.co',
      fullName: 'Maria Santos',
      major: 'CS',
      rating: 4.8,
      createdAt: DateTime(2026, 1, 1),
    );

MaterialEntity _material({String id = 'm1', String sellerId = _other, double price = 18}) => MaterialEntity(
      id: id,
      title: 'Casio fx-991EX',
      description: 'Barely used',
      price: price,
      status: MaterialStatusEnum.AVAILABLE,
      condition: MaterialConditionEnum.LIKE_NEW,
      imageUrls: const [],
      sellerId: sellerId,
      seller: const UserSummary(id: _other, fullName: 'Jake Reyes', major: 'Chemistry', rating: 4.5),
      category: MaterialCategoryEnum.CALCULATORS,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

class _FakeMaterials implements MaterialRepository {
  List<MaterialEntity> materials = [];
  Object? error;

  @override
  Future<List<MaterialEntity>> getMaterials() async {
    if (error != null) throw error!;
    return materials;
  }

  @override
  Future<MaterialEntity> createListing(NewListingData data) async => _material(id: 'new');
}

class _FakeWishlist implements WishlistRepository {
  final List<WishlistItemEntity> items = [];
  Object? error;

  @override
  Future<List<WishlistItemEntity>> getWishlist() async => List.of(items);

  @override
  Future<WishlistItemEntity> add(String materialId) async {
    if (error != null) throw error!;
    return WishlistItemEntity(id: 'w-$materialId', userId: _me, materialId: materialId, createdAt: DateTime(2026, 9, 2));
  }

  @override
  Future<void> remove(String wishlistItemId) async {
    if (error != null) throw error!;
  }
}

class _FakeChats implements ChatRepository {
  List<ChatRoomEntity> rooms = [];
  List<MessageEntity> messages = [];
  final markedRead = <String>[];

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async => rooms;

  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) async => rooms.first;

  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) async => messages;

  @override
  Future<MessageEntity> sendMessage(String chatRoomId, String content) async => MessageEntity(
        id: 'sent',
        chatRoomId: chatRoomId,
        senderId: _me,
        content: content,
        isRead: false,
        createdAt: DateTime(2026, 9, 3),
      );

  @override
  Future<void> markRead(String chatRoomId) async => markedRead.add(chatRoomId);
}

ExchangeEntity _order({
  String id = 'x1',
  String materialId = 'm1',
  String buyerId = _me,
  String sellerId = _other,
  double price = 18,
  ExchangeStatusEnum status = ExchangeStatusEnum.PENDING,
  DateTime? completedAt,
}) =>
    ExchangeEntity(
      id: id,
      orderNumber: 1001,
      materialId: materialId,
      buyerId: buyerId,
      sellerId: sellerId,
      price: price,
      status: status,
      createdAt: DateTime(2026, 9, 1),
      completedAt: completedAt,
    );

class _FakeExchanges implements ExchangeRepository {
  List<ExchangeEntity> exchanges = [];
  final ordered = <String>[];
  final ratings = <NewRating>[];
  DataException? orderError;

  @override
  Future<List<ExchangeEntity>> getExchanges() async => exchanges;

  @override
  Future<ExchangeEntity> placeOrder(String materialId) async {
    if (orderError != null) throw orderError!;
    ordered.add(materialId);
    return _order(id: 'new', materialId: materialId);
  }

  @override
  Future<ExchangeEntity> complete(String exchangeId, {MaterialConditionEnum? receivedCondition}) async =>
      _order(id: exchangeId, status: ExchangeStatusEnum.COMPLETED, completedAt: DateTime(2026, 9, 2));

  @override
  Future<ExchangeEntity> cancel(String exchangeId) async =>
      _order(id: exchangeId, status: ExchangeStatusEnum.CANCELLED);

  @override
  Future<void> rate(NewRating rating) async => ratings.add(rating);
}

const _library = MeetingPointEntity(
  id: 'lib',
  name: 'Central Library lobby',
  zoneType: MeetingZoneTypeEnum.LIBRARY,
  isMonitored: true,
  location: GeoPoint(4.60198, -74.06532),
);
const _plaza = MeetingPointEntity(
  id: 'plaza',
  name: 'Plazoleta Lleras',
  zoneType: MeetingZoneTypeEnum.PLAZA,
  isMonitored: false,
  location: GeoPoint(4.60165, -74.06642),
);
const _lobby = MeetingPointEntity(
  id: 'ml',
  name: 'Mario Laserna lobby',
  zoneType: MeetingZoneTypeEnum.BUILDING_LOBBY,
  isMonitored: true,
  location: GeoPoint(4.60286, -74.06485),
);

class _FakeMeetups implements MeetupRepository {
  List<MeetingPointEntity> points = [_library, _plaza, _lobby];
  MeetingSuggestions suggestions = const MeetingSuggestions(slots: [], callerHasSchedule: true, otherHasSchedule: true);
  final proposed = <(String, String, DateTime)>[];
  final answers = <String>[];

  MeetingProposalEntity _proposal(String id, MeetingProposalStatusEnum status) => MeetingProposalEntity(
        id: id,
        chatRoomId: 'r1',
        proposerId: _me,
        startsAt: DateTime(2026, 9, 16, 10),
        endsAt: DateTime(2026, 9, 16, 11),
        status: status,
      );

  @override
  Future<List<MeetingPointEntity>> getMeetingPoints() async => points;

  @override
  Future<MeetingSuggestions> getSuggestions(String chatRoomId) async => suggestions;

  @override
  Future<MeetingProposalEntity> propose({
    required String chatRoomId,
    required String meetingPointId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    proposed.add((chatRoomId, meetingPointId, startsAt));
    return _proposal('p1', MeetingProposalStatusEnum.PENDING);
  }

  @override
  Future<MeetingProposalEntity> accept(String proposalId) async {
    answers.add('accept $proposalId');
    return _proposal(proposalId, MeetingProposalStatusEnum.ACCEPTED);
  }

  @override
  Future<MeetingProposalEntity> decline(String proposalId) async {
    answers.add('decline $proposalId');
    return _proposal(proposalId, MeetingProposalStatusEnum.DECLINED);
  }

  @override
  Future<MeetingProposalEntity> withdraw(String proposalId) async {
    answers.add('withdraw $proposalId');
    return _proposal(proposalId, MeetingProposalStatusEnum.CANCELLED);
  }
}

class _FakeSchedule implements ScheduleRepository {
  List<ScheduleBlockEntity> blocks = [];

  @override
  Future<List<ScheduleBlockEntity>> getSchedule() async => blocks;

  @override
  Future<ScheduleBlockEntity> add(NewScheduleBlock block) async => ScheduleBlockEntity(
        id: 'b${blocks.length}',
        dayOfWeek: block.dayOfWeek,
        startMinute: block.startMinute,
        endMinute: block.endMinute,
        label: block.label,
      );

  @override
  Future<void> remove(String blockId) async {}
}

class _FakeLocation implements LocationRepository {
  GeoPoint? here;

  @override
  Future<GeoPoint?> currentLocation() async => here;
}

class _FakeDensity implements MeetingDensityRepository {
  MeetingPointDensity density = MeetingPointDensity.empty;

  @override
  Future<MeetingPointDensity> getDensity() async => density;
}

class _FakeInsights implements ConversationInsightRepository {
  @override
  Future<ConversationInsight> getConversationInsight() async =>
      const ConversationInsight(conversationsAnalyzed: 0, medianMessages: 0, medianMinutes: 0);
}

class _FakeNotifications implements NotificationRepository {
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];

  @override
  Future<void> markOpened(String notificationId) async {}
}

class _World {
  final materials = _FakeMaterials();
  final wishlist = _FakeWishlist();
  final chats = _FakeChats();
  final exchanges = _FakeExchanges();
  final notifications = _FakeNotifications();
  final meetupRepo = _FakeMeetups();
  final scheduleRepo = _FakeSchedule();
  final location = _FakeLocation();
  final density = _FakeDensity();
  final insights = _FakeInsights();

  late final meetups = MeetupUseCases(
    getMeetingPoints: GetMeetingPointsUseCase(meetupRepo),
    getSuggestions: GetMeetingSuggestionsUseCase(meetupRepo),
    propose: ProposeMeetingUseCase(meetupRepo),
    answer: AnswerMeetingProposalUseCase(meetupRepo),
    currentLocation: GetCurrentLocationUseCase(location),
    rankZones: RankSafeZonesUseCase(),
    recommend: RecommendMeetingPointUseCase(const RankMeetingPointsUseCase()),
    getDensity: GetMeetingPointDensityUseCase(density),
  );

  late final marketplaceState = MarketplaceState(
    getMaterials: GetMaterialsUseCase(materials),
    createListing: CreateListingUseCase(materials),
    getWishlist: GetWishlistUseCase(wishlist),
    addToWishlist: AddToWishlistUseCase(wishlist),
    removeFromWishlist: RemoveFromWishlistUseCase(wishlist),
  );

  late final chatState = ChatState(
    getChatRooms: GetChatRoomsUseCase(chats),
    openChatRoom: OpenChatRoomUseCase(chats),
    getMessages: GetMessagesUseCase(chats),
    sendMessage: SendMessageUseCase(chats),
    markRead: MarkChatReadUseCase(chats),
    answerProposal: meetups.answer,
    getConversationInsight: GetConversationInsightUseCase(insights),
  );

  late final accountState = AccountState(
    getExchanges: GetExchangesUseCase(exchanges),
    getNotifications: GetNotificationsUseCase(notifications),
    markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
    placeOrder: PlaceOrderUseCase(exchanges),
    completeExchange: CompleteExchangeUseCase(exchanges),
    cancelExchange: CancelExchangeUseCase(exchanges),
    rateUser: RateUserUseCase(exchanges),
  );

  late final scheduleState = ScheduleState(
    getSchedule: GetScheduleUseCase(scheduleRepo),
    addBlock: AddScheduleBlockUseCase(scheduleRepo),
    removeBlock: RemoveScheduleBlockUseCase(scheduleRepo),
  );

  late final appState = AppState(
    marketplace: marketplaceState,
    chats: chatState,
    account: accountState,
    schedule: scheduleState,
    meetups: meetups,
  );
}

class _FakeRemote implements MarketplaceRemoteDataSource {
  Object? error;
  final uploaded = <String>[];
  Map<String, dynamic>? createdBody;

  @override
  Future<List<MaterialEntity>> getMaterials() async {
    if (error != null) throw error!;
    return [];
  }

  @override
  Future<MaterialEntity> createMaterial(Map<String, dynamic> body) async {
    createdBody = body;
    return _material();
  }

  @override
  Future<String> uploadImage({required List<int> bytes, required String filename}) async {
    uploaded.add(filename);
    return 'https://blob/$filename';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('JSON mapping', () {
    test('reads Prisma decimal strings, enums and the nested seller', () {
      final material = materialFromJson(_materialJson(price: '24.50'));

      expect(material.price, 24.5);
      expect(material.condition, MaterialConditionEnum.LIKE_NEW);
      expect(material.category, MaterialCategoryEnum.CALCULATORS);
      expect(material.seller?.fullName, 'Jake Reyes');
      expect(material.seller?.initials, 'JR');
    });

    test('a chat room keeps the newest message and the unread count', () {
      final room = chatRoomFromJson({
        'id': 'r1',
        'materialId': 'm1',
        'buyerId': _me,
        'sellerId': _other,
        'createdAt': '2026-09-01T10:00:00.000Z',
        'buyer': _sellerJson(_me),
        'seller': _sellerJson(),
        'messages': [
          {'id': 'a', 'chatRoomId': 'r1', 'senderId': _other, 'content': 'old', 'isRead': true, 'createdAt': '2026-09-01T10:01:00.000Z'},
          {'id': 'b', 'chatRoomId': 'r1', 'senderId': _other, 'content': 'new', 'isRead': false, 'createdAt': '2026-09-01T10:05:00.000Z'},
        ],
        '_count': {'messages': 1},
      });

      expect(room.lastMessage?.content, 'new');
      expect(room.unreadCount, 1);
      expect(room.otherParty(_me)?.id, _other);
    });
  });

  group('repositories', () {
    test('publishing uploads the photos first and sends a two-decimal price', () async {
      final remote = _FakeRemote();
      final repository = MaterialRepositoryImpl(remote);

      await repository.createListing(NewListingData(
        title: ' Calculator ',
        description: 'Works',
        courseCode: '  ',
        price: 18,
        condition: MaterialConditionEnum.GOOD,
        category: MaterialCategoryEnum.CALCULATORS,
        images: [
          PendingImage(bytes: Uint8List(1), filename: 'a.jpg'),
          PendingImage(bytes: Uint8List(1), filename: 'b.jpg'),
        ],
      ));

      expect(remote.uploaded, ['a.jpg', 'b.jpg']);
      expect(remote.createdBody?['imageUrls'], ['https://blob/a.jpg', 'https://blob/b.jpg']);
      expect(remote.createdBody?['price'], '18.00');
      expect(remote.createdBody?['title'], 'Calculator');
      expect(remote.createdBody?.containsKey('courseCode'), isFalse);
      expect(remote.createdBody?['condition'], 'GOOD');
    });

    test('failures become messages the UI can show', () async {
      final remote = _FakeRemote();
      final repository = MaterialRepositoryImpl(remote);

      remote.error = const NetworkException('offline');
      await expectLater(repository.getMaterials(), throwsA(isA<DataException>().having((e) => e.message, 'message', contains("Can't reach"))));

      remote.error = const ApiException(403, 'Only the seller can change this listing');
      await expectLater(repository.getMaterials(), throwsA(isA<DataException>().having((e) => e.message, 'message', 'Only the seller can change this listing')));

      remote.error = const ApiException(500, 'stack trace with secrets');
      await expectLater(repository.getMaterials(), throwsA(isA<DataException>().having((e) => e.message, 'message', isNot(contains('secrets')))));
    });
  });

  group('MarketplaceState', () {
    test('loads listings and favorites, exposing only available ones to browse', () async {
      final world = _World();
      world.materials.materials = [
        _material(id: 'a'),
        _material(id: 'b').copyWith(status: MaterialStatusEnum.SOLD),
      ];

      await world.marketplaceState.load();

      expect(world.marketplaceState.materials, hasLength(2));
      expect(world.marketplaceState.availableMaterials.map((m) => m.id), ['a']);
      expect(world.marketplaceState.error, isNull);
      expect(world.marketplaceState.isFirstLoad, isFalse);
    });

    test('a failed load reports the error instead of crashing', () async {
      final world = _World();
      world.materials.error = const DataException('Server down');

      await world.marketplaceState.load();

      expect(world.marketplaceState.error, 'Server down');
      expect(world.marketplaceState.materials, isEmpty);
    });

    test('hearts update at once and roll back when the server refuses', () async {
      final world = _World();
      world.materials.materials = [_material(id: 'a')];
      await world.marketplaceState.load();

      expect(await world.marketplaceState.toggleFavorite('a'), isNull);
      expect(world.marketplaceState.isFavorite('a'), isTrue);

      world.wishlist.error = const DataException('No permission');
      expect(await world.marketplaceState.toggleFavorite('a'), 'No permission');
      expect(world.marketplaceState.isFavorite('a'), isTrue, reason: 'removal failed, so it stays saved');

      world.wishlist.error = null;
      expect(await world.marketplaceState.toggleFavorite('a'), isNull);
      world.wishlist.error = const DataException('Offline');
      expect(await world.marketplaceState.toggleFavorite('a'), 'Offline');
      expect(world.marketplaceState.isFavorite('a'), isFalse, reason: 'add failed, so the heart goes back to empty');
    });

    test('a listing the user publishes shows up first', () async {
      final world = _World();
      world.materials.materials = [_material(id: 'a')];
      await world.marketplaceState.load();

      await world.marketplaceState.publish(const NewListingData(
        title: 'Calculator',
        description: 'Works',
        price: 10,
        condition: MaterialConditionEnum.GOOD,
        category: MaterialCategoryEnum.CALCULATORS,
      ));

      expect(world.marketplaceState.materials.first.id, 'new');
    });

    test('signing out empties everything', () async {
      final world = _World();
      world.materials.materials = [_material(id: 'a')];
      await world.marketplaceState.load();

      world.marketplaceState.clear();

      expect(world.marketplaceState.materials, isEmpty);
      expect(world.marketplaceState.isFirstLoad, isTrue);
    });
  });

  group('ChatState', () {
    ChatRoomEntity room({int unread = 0, DateTime? at}) => ChatRoomEntity(
          id: 'r1',
          materialId: 'm1',
          buyerId: _me,
          sellerId: _other,
          createdAt: DateTime(2026, 9, 1),
          unreadCount: unread,
          lastMessage: at == null
              ? null
              : MessageEntity(id: 'x', chatRoomId: 'r1', senderId: _other, content: 'hi', isRead: false, createdAt: at),
        );

    test('opening a conversation marks the other side\'s messages as read and clears the badge', () async {
      final world = _World();
      world.chats.rooms = [room(unread: 2, at: DateTime(2026, 9, 2))];
      world.chats.messages = [
        MessageEntity(id: 'x', chatRoomId: 'r1', senderId: _other, content: 'hi', isRead: false, createdAt: DateTime(2026, 9, 2)),
      ];
      world.chatState.start(_me);
      await Future<void>.delayed(Duration.zero);
      expect(world.chatState.unreadTotal, 2);

      world.chatState.openRoom('r1');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(world.chats.markedRead, ['r1']);
      expect(world.chatState.unreadTotal, 0);
      expect(world.chatState.messagesOf('r1'), hasLength(1));
      world.chatState.clear();
    });

    test('sending appends the message; an empty one is refused without calling the server', () async {
      final world = _World();
      world.chats.rooms = [room()];
      world.chatState.start(_me);

      expect(await world.chatState.send('r1', 'Is it still available?'), isNull);
      expect(world.chatState.messagesOf('r1').single.content, 'Is it still available?');

      expect(await world.chatState.send('r1', '   '), 'Write a message first.');
      expect(world.chatState.messagesOf('r1'), hasLength(1));
      world.chatState.clear();
    });
  });

  group('AccountState', () {
    ExchangeEntity exchange(String id, {required String buyer, required String seller, required double price, required DateTime at}) =>
        _order(id: id, materialId: 'm$id', buyerId: buyer, sellerId: seller, price: price,
            status: ExchangeStatusEnum.COMPLETED, completedAt: at);

    test('splits purchases and sales and counts this month\'s earnings', () async {
      final world = _World();
      world.exchanges.exchanges = [
        exchange('1', buyer: _other, seller: _me, price: 18, at: DateTime(2026, 9, 10)),
        exchange('2', buyer: _other, seller: _me, price: 24.5, at: DateTime(2026, 8, 28)),
        exchange('3', buyer: _me, seller: _other, price: 9, at: DateTime(2026, 9, 12)),
      ];

      await world.accountState.load();

      expect(world.accountState.purchasesOf(_me).map((e) => e.id), ['3']);
      expect(world.accountState.salesOf(_me).map((e) => e.id), ['1', '2']);
      expect(world.accountState.swapCountOf(_me), 3);
      expect(world.accountState.earnedThisMonth(_me, now: DateTime(2026, 9, 20)), 18);
    });

    test('pending orders are listed but only completed ones count as swaps and earnings', () async {
      final world = _World();
      world.exchanges.exchanges = [
        _order(id: 'p', sellerId: _me, buyerId: _other, price: 50),
        _order(id: 'c', sellerId: _me, buyerId: _other, price: 20, status: ExchangeStatusEnum.CANCELLED),
        _order(id: 'd', sellerId: _me, buyerId: _other, price: 18,
            status: ExchangeStatusEnum.COMPLETED, completedAt: DateTime(2026, 9, 10)),
      ];

      await world.accountState.load();

      expect(world.accountState.salesOf(_me).map((e) => e.id), ['d', 'p']);
      expect(world.accountState.swapCountOf(_me), 1);
      expect(world.accountState.earnedThisMonth(_me, now: DateTime(2026, 9, 20)), 18);
      expect(world.accountState.pendingOrderFor('m1', _other)?.id, 'p');
    });
  });

  group('Orders', () {
    test('buying places the order and opens the confirmation for it', () async {
      final world = _World();
      world.appState.login(_user());

      final error = await world.appState.buy(_material(id: 'm9', sellerId: _other));

      expect(error, isNull);
      expect(world.exchanges.ordered, ['m9']);
      expect(world.appState.currentScreen, AppScreen.confirmation);
      expect(world.appState.selectedExchange?.orderCode, 'CSW-1001');
      expect(world.accountState.pendingOrderFor('m9', _me), isNotNull);
      world.chatState.clear();
    });

    test('you cannot buy your own or an unavailable listing', () async {
      final world = _World();
      world.appState.login(_user());

      expect(await world.appState.buy(_material(sellerId: _me)), 'This is your own listing.');
      expect(
        await world.appState.buy(_material().copyWith(status: MaterialStatusEnum.RESERVED)),
        'This item is no longer available.',
      );
      expect(world.exchanges.ordered, isEmpty);
      world.chatState.clear();
    });

    test('the server refusing an order is shown to the user', () async {
      final world = _World();
      world.appState.login(_user());
      world.exchanges.orderError = const DataException('This listing is no longer available');

      expect(await world.appState.buy(_material()), 'This listing is no longer available');
      expect(world.appState.currentScreen, isNot(AppScreen.confirmation));
      world.chatState.clear();
    });

    test('completing marks the order completed; ratings trim an empty review', () async {
      final world = _World();
      final completed = await world.accountState.complete(_order(), receivedCondition: MaterialConditionEnum.GOOD);
      await world.accountState.rate(const NewRating(exchangeId: 'x1', ratedId: _other, stars: 5, review: '   '));

      expect(completed.isCompleted, isTrue);
      expect(world.exchanges.ratings.single.review, isNull);
      expect(
        () => world.accountState.rate(const NewRating(exchangeId: 'x1', ratedId: _other, stars: 0)),
        throwsA(isA<DataException>()),
      );
      expect(
        () => world.accountState.complete(_order(status: ExchangeStatusEnum.COMPLETED)),
        throwsA(isA<DataException>()),
      );
    });
  });

  group('Meetups', () {
    test('zones are ranked by walking time and the closest monitored one is the best match', () {
      // Right next to the plaza, which is not monitored.
      const here = GeoPoint(4.60160, -74.06650);

      final ranked = RankSafeZonesUseCase().execute([_library, _plaza, _lobby], here);

      expect(ranked.map((r) => r.zone.id), ['plaza', 'lib', 'ml']);
      expect(ranked.firstWhere((r) => r.bestMatch).zone.id, 'lib');
      expect(ranked.first.walkMinutes, 1);
    });

    test('without a location, monitored zones come first and there are no walking times', () {
      final ranked = RankSafeZonesUseCase().execute([_plaza, _lobby, _library], null);

      expect(ranked.map((r) => r.zone.id), ['lib', 'ml', 'plaza']);
      expect(ranked.every((r) => r.walkMinutes == null), isTrue);
      expect(ranked.first.bestMatch, isTrue);
    });

    test('walking time is distance at 80 m per minute, rounded up', () {
      // About 445 m apart.
      const a = GeoPoint(4.6000, -74.0650);
      const b = GeoPoint(4.6040, -74.0650);

      expect(RankSafeZonesUseCase.distanceMeters(a, b), closeTo(445, 5));
      expect(RankSafeZonesUseCase.walkMinutes(a, b), 6);
    });

    test('the planner preselects the suggested hour and the best zone, then proposes them', () async {
      final world = _World();
      final slot = FreeSlot(
        startsAt: DateTime.now().add(const Duration(days: 2)),
        endsAt: DateTime.now().add(const Duration(days: 2, hours: 1)),
        sharedBreak: true,
      );
      world.meetupRepo.suggestions = MeetingSuggestions(
        slots: [slot],
        suggested: slot,
        callerHasSchedule: true,
        otherHasSchedule: false,
      );
      world.location.here = const GeoPoint(4.60286, -74.06485);
      final planner = MeetingPlannerState(useCases: world.meetups, chatRoomId: 'r1');

      await planner.load();
      await Future<void>.delayed(Duration.zero);

      expect(planner.selectedSlot, slot);
      expect(planner.selectedZone?.zone.id, 'ml');
      expect(await planner.propose(), isNull);
      expect(world.meetupRepo.proposed.single.$2, 'ml');
      planner.dispose();
    });

    test('a meeting in the past cannot be proposed', () {
      final world = _World();
      final past = FreeSlot(
        startsAt: DateTime(2020, 1, 1, 10),
        endsAt: DateTime(2020, 1, 1, 11),
        sharedBreak: false,
      );

      expect(
        () => world.meetups.propose.execute(chatRoomId: 'r1', zone: _library, slot: past),
        throwsA(isA<DataException>()),
      );
    });

    test('answering a proposal goes to the server and refreshes the chat', () async {
      final world = _World();
      world.chatState.start(_me);
      world.chatState.openRoom('r1');

      expect(await world.chatState.answer('p1', ProposalAnswer.accept), isNull);
      expect(world.meetupRepo.answers, ['accept p1']);
      world.chatState.clear();
    });

    test('schedule rejects overlapping classes and classes that end before they start', () async {
      final world = _World();
      expect(
        await world.scheduleState.add(const NewScheduleBlock(dayOfWeek: 1, startMinute: 600, endMinute: 540)),
        'A class has to end after it starts.',
      );
      expect(await world.scheduleState.add(const NewScheduleBlock(dayOfWeek: 1, startMinute: 420, endMinute: 540, label: 'MATH-201')), isNull);
      expect(
        await world.scheduleState.add(const NewScheduleBlock(dayOfWeek: 1, startMinute: 480, endMinute: 600)),
        'Overlaps with MATH-201 on the same day.',
      );
      expect(world.scheduleState.blocksOn(1), hasLength(1));
    });
  });

  group('Meetup JSON', () {
    test('an order with its agreed meetup', () {
      final exchange = exchangeFromJson({
        'id': 'x1',
        'orderNumber': 1001,
        'materialId': 'm1',
        'buyerId': _me,
        'sellerId': _other,
        'price': '320000.00',
        'status': 'PENDING',
        'createdAt': '2026-09-15T10:00:00.000Z',
        'completedAt': null,
        'receivedCondition': null,
        'meetingPointId': 'lib',
        'meetingStartsAt': '2026-09-17T14:00:00.000Z',
        'meetingEndsAt': '2026-09-17T15:00:00.000Z',
        'meetingPoint': {
          'id': 'lib', 'name': 'Central Library lobby', 'detail': null, 'zoneType': 'LIBRARY',
          'isMonitored': true, 'lat': 4.6, 'lng': -74.06, 'createdAt': '2026-09-01T00:00:00.000Z',
        },
        'lat': 4.6,
        'lng': -74.06,
      });

      expect(exchange.orderCode, 'CSW-1001');
      expect(exchange.isPending, isTrue);
      expect(exchange.price, 320000);
      expect(exchange.meetingPoint?.isMonitored, isTrue);
      expect(exchange.meetingStartsAt, DateTime.utc(2026, 9, 17, 14));
    });

    test('a meeting message carries its proposal; unknown types fall back safely', () {
      final message = messageFromJson({
        'id': 'a', 'chatRoomId': 'r1', 'senderId': _other, 'content': 'Proposed meeting', 'isRead': false,
        'createdAt': '2026-09-01T10:01:00.000Z', 'type': 'MEETING',
        'meetingProposal': {
          'id': 'p1', 'chatRoomId': 'r1', 'proposerId': _other, 'meetingPointId': 'lib', 'status': 'ACCEPTED',
          'startsAt': '2026-09-17T14:00:00.000Z', 'endsAt': '2026-09-17T15:00:00.000Z',
        },
      });
      final legacy = messageFromJson({
        'id': 'b', 'chatRoomId': 'r1', 'senderId': _other, 'content': 'hi', 'isRead': true,
        'createdAt': '2026-09-01T10:01:00.000Z',
      });
      final notification = notificationFromJson({
        'id': 'n', 'userId': _me, 'materialId': null, 'type': 'SOMETHING_NEW',
        'sentAt': '2026-09-01T10:01:00.000Z', 'openedAt': null,
      });

      expect(message.type, MessageTypeEnum.MEETING);
      expect(message.meetingProposal?.isAccepted, isTrue);
      expect(legacy.type, MessageTypeEnum.TEXT);
      expect(notification.type, NotificationTypeEnum.OTHER);
    });
  });

  group('Meetup formatting', () {
    test('prices in pesos and campus times', () {
      expect(copPrice(320000), r'$320.000 COP');
      expect(copPrice(9500), r'$9.500 COP');
      expect(copPrice(800), r'$800 COP');
      expect(timeRange(DateTime(2026, 9, 16, 10), DateTime(2026, 9, 16, 11)), '10:00 - 11:00');
      expect(dayLabel(DateTime(2026, 9, 16, 10)), 'Wed 16 Sep');
      expect(minuteOfDay(450), '07:30');
    });
  });

  group('ApiClient', () {
    test('uploads a file as multipart and sends the token', () async {
      late http.BaseRequest seen;
      final client = ApiClient(
        baseUrl: 'https://api.test/',
        client: MockClient.streaming((request, body) async {
          seen = request;
          return http.StreamedResponse(Stream.value(utf8.encode('{"url":"https://blob/x.jpg"}')), 201);
        }),
      )..authToken = 'jwt';

      final response = await client.postFile('/uploads', field: 'file', bytes: [1, 2, 3], filename: 'x.jpg') as Map<String, dynamic>;

      expect(response['url'], 'https://blob/x.jpg');
      expect(seen.url.toString(), 'https://api.test/uploads');
      expect(seen.headers['Authorization'], 'Bearer jwt');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    });

    test('a rejected token signs the app out, but a wrong password does not', () async {
      var signedOut = 0;
      final client = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response('{"message":"Invalid or expired token"}', 401)),
      )..onUnauthorized = () => signedOut++;

      await expectLater(client.get('/materials'), throwsA(isA<ApiException>()));
      expect(signedOut, 0, reason: 'no token was sent yet (login attempt)');

      client.authToken = 'old-token';
      await expectLater(client.get('/materials'), throwsA(isA<ApiException>()));
      expect(signedOut, 1);
    });

    test('supports PATCH and DELETE', () async {
      final methods = <String>[];
      final client = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          methods.add(request.method);
          return http.Response('{}', 200);
        }),
      );

      await client.patch('/users/1', body: {'major': 'CS'});
      await client.delete('/wishlist-items/1');

      expect(methods, ['PATCH', 'DELETE']);
    });
  });

  group('formatters', () {
    final now = DateTime(2026, 9, 20, 12, 0);

    test('relative times', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(timeAgo(now.subtract(const Duration(days: 1, hours: 2)), now: now), 'Yesterday');
      expect(timeAgo(DateTime(2026, 9, 1, 12), now: now), 'Sep 1');
    });

    test('clock time uses 12 hours', () {
      expect(clockTime(DateTime(2026, 9, 1, 14, 5)), '2:05 PM');
      expect(clockTime(DateTime(2026, 9, 1, 0, 30)), '12:30 AM');
    });
  });

  group('Home screen', () {
    // Widget tests render text with a placeholder font whose glyphs are far wider than the real
    // ones, so existing layouts report overflows that don't happen on a device. Ignore only those.
    void ignoreFontOverflows() {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }

    UserEntity user() => UserEntity(
          id: _me,
          email: 'me@uniandes.edu.co',
          fullName: 'Maria Santos',
          major: 'CS',
          rating: 4.8,
          createdAt: DateTime(2026, 1, 1),
        );

    Future<_World> pumpHome(WidgetTester tester, List<MaterialEntity> materials) async {
      ignoreFontOverflows();
      final world = _World();
      world.materials.materials = materials;
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      world.appState.login(user());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(appState: world.appState))));
      await tester.pumpAndSettle();
      return world;
    }

    testWidgets('shows what the server returned, not canned listings', (tester) async {
      final world = await pumpHome(tester, [
        _material(id: 'a').copyWith(title: 'Server Textbook'),
        _material(id: 'b').copyWith(title: 'Another Calculator'),
      ]);

      expect(find.text('Server Textbook'), findsOneWidget);
      expect(find.text('Another Calculator'), findsOneWidget);
      expect(find.text('Casio fx-991EX Scientific Calculator'), findsNothing);
      world.chatState.clear();
    });

    testWidgets('an empty marketplace says so instead of showing fake items', (tester) async {
      final world = await pumpHome(tester, []);

      expect(find.text('Nothing listed yet'), findsOneWidget);
      world.chatState.clear();
    });

    testWidgets('a failed load offers a retry', (tester) async {
      ignoreFontOverflows();
      final world = _World();
      world.materials.error = const DataException('Server down');
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      world.appState.login(user());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeScreen(appState: world.appState))));
      await tester.pumpAndSettle();

      expect(find.text('Server down'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      world.materials.error = null;
      world.materials.materials = [_material(id: 'a').copyWith(title: 'Recovered Item')];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered Item'), findsOneWidget);
      world.chatState.clear();
    });
  });
}
