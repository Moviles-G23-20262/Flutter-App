import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/Data/Models/marketplace_models.dart';
import 'package:flutter_front_end/Data/Repositories/marketplace_repositories_impl.dart';
import 'package:flutter_front_end/Data/data_sources/marketplace_remote_data_source.dart';
import 'package:flutter_front_end/Domain/Entities/chat_room_entity.dart';
import 'package:flutter_front_end/Domain/Entities/exchange_entity.dart';
import 'package:flutter_front_end/Domain/Entities/material_entity.dart';
import 'package:flutter_front_end/Domain/Entities/new_listing_data.dart';
import 'package:flutter_front_end/Domain/Entities/notification_entity.dart';
import 'package:flutter_front_end/Domain/Entities/user_entity.dart';
import 'package:flutter_front_end/Domain/Entities/user_summary.dart';
import 'package:flutter_front_end/Domain/Entities/wishlist_item_entity.dart';
import 'package:flutter_front_end/Domain/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/Domain/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/Domain/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/Presentation/Screens/home_screen.dart';
import 'package:flutter_front_end/Presentation/State%20Management/account_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/app_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/chat_state.dart';
import 'package:flutter_front_end/Presentation/State%20Management/marketplace_state.dart';
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

class _FakeExchanges implements ExchangeRepository {
  List<ExchangeEntity> exchanges = [];

  @override
  Future<List<ExchangeEntity>> getExchanges() async => exchanges;
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
  );

  late final accountState = AccountState(
    getExchanges: GetExchangesUseCase(exchanges),
    getNotifications: GetNotificationsUseCase(notifications),
    markNotificationOpened: MarkNotificationOpenedUseCase(notifications),
  );

  late final appState = AppState(marketplace: marketplaceState, chats: chatState, account: accountState);
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
        ExchangeEntity(id: id, materialId: 'm$id', buyerId: buyer, sellerId: seller, price: price, completedAt: at);

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
