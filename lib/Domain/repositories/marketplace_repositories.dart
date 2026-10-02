import '../Entities/chat_room_entity.dart';
import '../Entities/exchange_entity.dart';
import '../Entities/material_entity.dart';
import '../Entities/new_listing_data.dart';
import '../Entities/notification_entity.dart';
import '../Entities/wishlist_item_entity.dart';

// All of these throw `DataException` (with a user-presentable message) when the request fails.

abstract class MaterialRepository {
  /// Every listing, newest first.
  Future<List<MaterialEntity>> getMaterials();

  /// Uploads the photos, then creates the listing as the signed-in user.
  Future<MaterialEntity> createListing(NewListingData data);
}

abstract class WishlistRepository {
  Future<List<WishlistItemEntity>> getWishlist();

  /// Saving something twice is harmless.
  Future<WishlistItemEntity> add(String materialId);

  Future<void> remove(String wishlistItemId);
}

abstract class ChatRepository {
  /// The signed-in user's conversations, with last message and unread count.
  Future<List<ChatRoomEntity>> getChatRooms();

  /// The conversation with the seller of [materialId]; reuses it if it already exists.
  Future<ChatRoomEntity> openChatRoom(String materialId);

  Future<List<MessageEntity>> getMessages(String chatRoomId);

  Future<MessageEntity> sendMessage(String chatRoomId, String content);

  /// Marks the other person's messages as read.
  Future<void> markRead(String chatRoomId);
}

abstract class ExchangeRepository {
  /// Completed exchanges where the signed-in user is buyer or seller.
  Future<List<ExchangeEntity>> getExchanges();
}

abstract class NotificationRepository {
  Future<List<NotificationEntity>> getNotifications();

  Future<void> markOpened(String notificationId);
}
