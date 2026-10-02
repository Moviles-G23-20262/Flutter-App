import '../../core/network/api_client.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/rating_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../../Domain/Entities/wishlist_item_entity.dart';
import '../Models/marketplace_models.dart';

/// Every call the signed-in user makes against the marketplace endpoints.
/// Errors surface as [ApiException] / [NetworkException];
/// the repositories translate them.
abstract class MarketplaceRemoteDataSource {
  Future<List<MaterialEntity>> getMaterials();

  Future<MaterialEntity> createMaterial(
    Map<String, dynamic> body,
  );

  /// Uploads a photo and returns its public URL.
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
  });

  Future<List<WishlistItemEntity>> getWishlist();

  Future<WishlistItemEntity> addToWishlist(
    String materialId,
  );

  Future<void> removeFromWishlist(
    String wishlistItemId,
  );

  Future<List<ChatRoomEntity>> getChatRooms();

  Future<ChatRoomEntity> openChatRoom(
    String materialId,
  );

  Future<List<MessageEntity>> getMessages(
    String chatRoomId,
  );

  Future<MessageEntity> sendMessage(
    String chatRoomId,
    String content,
  );

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

  // Crear una valoración
  Future<void> createRating(
    Map<String, dynamic> body,
  );

  // Obtener las valoraciones de un usuario
  Future<List<RatingEntity>> getRatingsForUser(
    String userId,
  );

  Future<List<NotificationEntity>> getNotifications();

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
        await apiClient.get('/materials'),
        materialFromJson,
      );

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
        await apiClient.get('/wishlist-items'),
        wishlistItemFromJson,
      );

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
        await apiClient.get('/chatrooms'),
        chatRoomFromJson,
      );

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
        await apiClient.get(
          '/messages?chatRoomId=$chatRoomId',
        ),
        messageFromJson,
      );

  @override
  Future<MessageEntity> sendMessage(
    String chatRoomId,
    String content,
  ) async =>
      messageFromJson(
        await apiClient.post(
          '/messages',
          body: {
            'chatRoomId': chatRoomId,
            'content': content,
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
        await apiClient.get('/notifications'),
        notificationFromJson,
      );

  @override
  Future<void> markNotificationOpened(
    String notificationId,
  ) async {
    await apiClient.post(
      '/notifications/$notificationId/open',
    );
  }
}