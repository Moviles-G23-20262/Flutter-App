import '../../app/network/api_client.dart';
import '../dto/marketplace_models.dart';
import '../entities/chat_room_entity.dart';
import '../entities/exchange_entity.dart';
import '../entities/material_entity.dart';
import '../entities/notification_entity.dart';
import '../entities/rating_entity.dart';
import '../entities/wishlist_item_entity.dart';

abstract class MarketplaceRemoteDataSource {
  Future<List<MaterialEntity>> getMaterials();
  Future<Object?> getMaterialsJson();

  Future<MaterialEntity> createMaterial(
    Map<String, dynamic> body,
  );

  /// Uploads a photo and returns its public URL.
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
  });

  Future<List<WishlistItemEntity>> getWishlist();

  /// The `GET /wishlist-items` answer as it came, for the saved copy.
  Future<Object?> getWishlistJson();

  Future<WishlistItemEntity> addToWishlist(
    String materialId,
  );

  Future<void> removeFromWishlist(
    String wishlistItemId,
  );

  Future<List<ChatRoomEntity>> getChatRooms();
  Future<Object?> getChatRoomsJson();

  Future<ChatRoomEntity> openChatRoom(
    String materialId,
  );

  Future<List<MessageEntity>> getMessages(
    String chatRoomId,
  );
  Future<Object?> getMessagesJson(
    String chatRoomId,
  );

  Future<MessageEntity> sendMessage(
    String chatRoomId,
    String content, {
    String? id,
    DateTime? clientCreatedAt,
  });

  Future<void> markChatRead(
    String chatRoomId,
  );

  Future<List<ExchangeEntity>> getExchanges();

  Future<ExchangeEntity> placeOrder(
    String materialId,
  );

  Future<ExchangeEntity> completeExchange(
    String exchangeId, {
    String? receivedCondition,
  });

  Future<ExchangeEntity> cancelExchange(
    String exchangeId,
  );

  Future<void> createRating(
    Map<String, dynamic> body,
  );

  Future<List<RatingEntity>> getRatingsForUser(
    String userId,
  );

  Future<List<NotificationEntity>> getNotifications();

  /// The `GET /notifications` answer as it came, for the saved copy.
  Future<Object?> getNotificationsJson();

  Future<void> markNotificationOpened(
    String notificationId,
  );
}

class MarketplaceRemoteDataSourceImpl
    implements MarketplaceRemoteDataSource {
  final ApiClient apiClient;

  MarketplaceRemoteDataSourceImpl({
    required this.apiClient,
  });

  @override
  Future<List<MaterialEntity>> getMaterials() async =>
      parseList(
        await getMaterialsJson(),
        materialFromJson,
      );

  @override
  Future<Object?> getMaterialsJson() => apiClient.get('/materials');

  @override
  Future<MaterialEntity> createMaterial(
    Map<String, dynamic> body,
  ) async =>
      materialFromJson(
        await apiClient.post(
          '/materials',
          body: body,
        ) as Json,
      );

  @override
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await apiClient.postFile(
      '/uploads',
      field: 'file',
      bytes: bytes,
      filename: filename,
    ) as Json;

    return response['url'] as String;
  }

  @override
  Future<List<WishlistItemEntity>> getWishlist() async =>
      parseList(
        await getWishlistJson(),
        wishlistItemFromJson,
      );

  @override
  Future<Object?> getWishlistJson() => apiClient.get('/wishlist-items');

  @override
  Future<WishlistItemEntity> addToWishlist(
    String materialId,
  ) async =>
      wishlistItemFromJson(
        await apiClient.post(
          '/wishlist-items',
          body: {
            'materialId': materialId,
          },
        ) as Json,
      );

  @override
  Future<void> removeFromWishlist(
    String wishlistItemId,
  ) async {
    await apiClient.delete(
      '/wishlist-items/$wishlistItemId',
    );
  }

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async =>
      parseList(
        await getChatRoomsJson(),
        chatRoomFromJson,
      );

  @override
  Future<Object?> getChatRoomsJson() => apiClient.get('/chatrooms');

  @override
  Future<ChatRoomEntity> openChatRoom(
    String materialId,
  ) async =>
      chatRoomFromJson(
        await apiClient.post(
          '/chatrooms',
          body: {
            'materialId': materialId,
          },
        ) as Json,
      );

  @override
  Future<List<MessageEntity>> getMessages(
    String chatRoomId,
  ) async =>
      parseList(
        await getMessagesJson(chatRoomId),
        messageFromJson,
      );

  @override
  Future<Object?> getMessagesJson(String chatRoomId) =>
      apiClient.get('/messages?chatRoomId=$chatRoomId');

  @override
  Future<MessageEntity> sendMessage(
    String chatRoomId,
    String content, {
    String? id,
    DateTime? clientCreatedAt,
  }) async =>
      messageFromJson(
        await apiClient.post(
          '/messages',
          body: {
            if (id != null) 'id': id,
            'chatRoomId': chatRoomId,
            'content': content,
            if (clientCreatedAt != null)
              'clientCreatedAt': clientCreatedAt.toIso8601String(),
          },
        ) as Json,
      );

  @override
  Future<void> markChatRead(
    String chatRoomId,
  ) async {
    await apiClient.post(
      '/chatrooms/$chatRoomId/read',
    );
  }

  @override
  Future<List<ExchangeEntity>> getExchanges() async =>
      parseList(
        await apiClient.get('/exchanges'),
        exchangeFromJson,
      );

  @override
  Future<ExchangeEntity> placeOrder(
    String materialId,
  ) async =>
      exchangeFromJson(
        await apiClient.post(
          '/exchanges/orders',
          body: {
            'materialId': materialId,
          },
        ) as Json,
      );

  @override
  Future<ExchangeEntity> completeExchange(
    String exchangeId, {
    String? receivedCondition,
  }) async =>
      exchangeFromJson(
        await apiClient.post(
          '/exchanges/$exchangeId/complete',
          body: {
            if (receivedCondition != null)
              'receivedCondition': receivedCondition,
          },
        ) as Json,
      );

  @override
  Future<ExchangeEntity> cancelExchange(
    String exchangeId,
  ) async =>
      exchangeFromJson(
        await apiClient.post(
          '/exchanges/$exchangeId/cancel',
        ) as Json,
      );

  @override
  Future<void> createRating(
    Map<String, dynamic> body,
  ) async {
    await apiClient.post(
      '/ratings',
      body: body,
    );
  }

  @override
  Future<List<RatingEntity>> getRatingsForUser(
    String userId,
  ) async {
    return parseList(
      await apiClient.get(
        '/ratings/user/$userId',
      ),
      ratingFromJson,
    );
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      parseList(
        await getNotificationsJson(),
        notificationFromJson,
      );

  @override
  Future<Object?> getNotificationsJson() => apiClient.get('/notifications');

  @override
  Future<void> markNotificationOpened(
    String notificationId,
  ) async {
    await apiClient.post(
      '/notifications/$notificationId/open',
    );
  }
}
