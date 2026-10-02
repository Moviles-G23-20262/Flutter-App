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
/// Shared by every repository that talks to the API.
Future<T> guardRequest<T>(Future<T> Function() request) async {
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
  Future<List<MaterialEntity>> getMaterials() => guardRequest(remote.getMaterials);

  @override
  Future<MaterialEntity> createListing(NewListingData data) => guardRequest(() async {
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
  Future<List<WishlistItemEntity>> getWishlist() => guardRequest(remote.getWishlist);

  @override
  Future<WishlistItemEntity> add(String materialId) => guardRequest(() => remote.addToWishlist(materialId));

  @override
  Future<void> remove(String wishlistItemId) => guardRequest(() => remote.removeFromWishlist(wishlistItemId));
}

class ChatRepositoryImpl implements ChatRepository {
  final MarketplaceRemoteDataSource remote;

  ChatRepositoryImpl(this.remote);

  @override
  Future<List<ChatRoomEntity>> getChatRooms() => guardRequest(remote.getChatRooms);

  @override
  Future<ChatRoomEntity> openChatRoom(String materialId) => guardRequest(() => remote.openChatRoom(materialId));

  @override
  Future<List<MessageEntity>> getMessages(String chatRoomId) => guardRequest(() => remote.getMessages(chatRoomId));

  @override
  Future<MessageEntity> sendMessage(String chatRoomId, String content) =>
      guardRequest(() => remote.sendMessage(chatRoomId, content));

  @override
  Future<void> markRead(String chatRoomId) => guardRequest(() => remote.markChatRead(chatRoomId));
}

class ExchangeRepositoryImpl implements ExchangeRepository {
  final MarketplaceRemoteDataSource remote;

  ExchangeRepositoryImpl(this.remote);

  @override
  Future<List<ExchangeEntity>> getExchanges() => guardRequest(remote.getExchanges);

  @override
  Future<ExchangeEntity> placeOrder(String materialId) => guardRequest(() => remote.placeOrder(materialId));

  @override
  Future<ExchangeEntity> complete(String exchangeId, {MaterialConditionEnum? receivedCondition}) =>
      guardRequest(() => remote.completeExchange(exchangeId, receivedCondition: receivedCondition?.name));

  @override
  Future<ExchangeEntity> cancel(String exchangeId) => guardRequest(() => remote.cancelExchange(exchangeId));

  @override
  Future<void> rate(NewRating rating) => guardRequest(() => remote.createRating({
        'exchangeId': rating.exchangeId,
        'ratedId': rating.ratedId,
        'stars': rating.stars,
        'tags': rating.tags,
        'review': ?rating.review,
      }));
}

class NotificationRepositoryImpl implements NotificationRepository {
  final MarketplaceRemoteDataSource remote;

  NotificationRepositoryImpl(this.remote);

  @override
  Future<List<NotificationEntity>> getNotifications() => guardRequest(remote.getNotifications);

  @override
  Future<void> markOpened(String notificationId) => guardRequest(() => remote.markNotificationOpened(notificationId));
}
