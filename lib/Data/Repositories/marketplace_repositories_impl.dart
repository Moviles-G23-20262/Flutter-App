import '../../core/network/api_client.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/new_listing_data.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../../Domain/Entities/wishlist_item_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/repositories/marketplace_repositories.dart';
import '../data_sources/marketplace_remote_data_source.dart';

/// Runs [request], turning transport and HTTP failures into a [DataException] the UI can show.
Future<T> _guard<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on NetworkException {
    throw const DataException("Can't reach the server. Check your connection and try again.");
  } on ApiException catch (e) {
    switch (e.statusCode) {
      case 400:
      case 403:
      case 404:
      case 409:
      case 413:
        throw DataException(e.message);
      case 401:
        throw const DataException('Your session expired. Please log in again.');
      default:
        throw const DataException('Something went wrong on our side. Please try again later.');
    }
  }
}

class MaterialRepositoryImpl implements MaterialRepository {
  final MarketplaceRemoteDataSource remote;

  MaterialRepositoryImpl(this.remote);

  @override
  Future<List<MaterialEntity>> getMaterials() => _guard(remote.getMaterials);

  @override
  Future<MaterialEntity> createListing(NewListingData data) => _guard(() async {
        final imageUrls = <String>[];
        for (final image in data.images) {
          imageUrls.add(await remote.uploadImage(bytes: image.bytes, filename: image.filename));
        }
        return remote.createMaterial({
          'title': data.title.trim(),
          'description': data.description.trim(),
          if (data.courseCode != null && data.courseCode!.trim().isNotEmpty)
            'courseCode': data.courseCode!.trim(),
          // The API validates prices as decimal strings with at most two decimals.
          'price': data.price.toStringAsFixed(2),
          'condition': data.condition.name,
          'category': data.category.name,
          'imageUrls': imageUrls,
        });
      });
}

class WishlistRepositoryImpl implements WishlistRepository {
  final MarketplaceRemoteDataSource remote;

  WishlistRepositoryImpl(this.remote);

  @override
  Future<List<WishlistItemEntity>> getWishlist() => _guard(remote.getWishlist);

  @override
  Future<WishlistItemEntity> add(String materialId) => _guard(() => remote.addToWishlist(materialId));

  @override
  Future<void> remove(String wishlistItemId) => _guard(() => remote.removeFromWishlist(wishlistItemId));
}

class ChatRepositoryImpl implements ChatRepository {
  final MarketplaceRemoteDataSource remote;

  ChatRepositoryImpl(this.remote);

  @override
  Future<List<ChatRoomEntity>> getChatRooms() => _guard(remote.getChatRooms);

  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) => _guard(() => remote.openChatRoom(materialId));

  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) => _guard(() => remote.getMessages(chatRoomId));

  @override
  Future<MessageEntity> sendMessage(String chatRoomId, String content) =>
      _guard(() => remote.sendMessage(chatRoomId, content));

  @override
  Future<void> markRead(String chatRoomId) => _guard(() => remote.markChatRead(chatRoomId));
}

class ExchangeRepositoryImpl implements ExchangeRepository {
  final MarketplaceRemoteDataSource remote;

  ExchangeRepositoryImpl(this.remote);

  @override
  Future<List<ExchangeEntity>> getExchanges() => _guard(remote.getExchanges);
}

class NotificationRepositoryImpl implements NotificationRepository {
  final MarketplaceRemoteDataSource remote;

  NotificationRepositoryImpl(this.remote);

  @override
  Future<List<NotificationEntity>> getNotifications() => _guard(remote.getNotifications);

  @override
  Future<void> markOpened(String notificationId) => _guard(() => remote.markNotificationOpened(notificationId));
}
