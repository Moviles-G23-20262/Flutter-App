import '../../../app/network/api_client.dart';

import 'dart:async';

import '../../entities/cached_list.dart';
import '../../entities/chat_room_entity.dart';
import '../../entities/exchange_entity.dart';
import '../../entities/material_entity.dart';
import '../../entities/new_listing_data.dart';
import '../../entities/notification_entity.dart';
import '../../entities/rating_entity.dart';
import '../../entities/wishlist_item_entity.dart';

import '../../exceptions/data_exceptions.dart';
import '../marketplace_repositories.dart';

import '../../data_sources/marketplace_remote_data_source.dart';
import '../../dto/marketplace_models.dart';
import '../../data_sources/local/response_cache.dart';
import '../../services/session_owner.dart';

/// Runs [request], turning transport and HTTP failures into a
/// [DataException] the UI can show.
///
/// Shared by every repository that talks to the API.
Future<T> guardRequest<T>(
  Future<T> Function() request,
) async {
  try {
    return await request();
  } on NetworkException {
    throw const NoConnectionException();
  } on ApiException catch (e) {
    switch (e.statusCode) {
      case 400:
      case 403:
      case 404:
      case 409:
      case 413:
        throw DataException(e.message);

      case 401:
        throw const DataException(
          'Your session expired. Please log in again.',
        );

      default:
        throw const DataException(
          'Something went wrong on our side. Please try again later.',
        );
    }
  }
}

/// Network falling back to the copy saved for the signed-in user.
///
/// Without a [cache] (or nobody signed in) it is just the network. After a change the copy is
/// refreshed in the background, so a restart offline does not show what was just undone.
Future<CachedList<T>> _cachedList<T>({
  required ResponseCache? cache,
  required SessionOwner? owner,
  required String key,
  required Future<Object?> Function() fetch,
  required T Function(Json json) parse,
}) {
  final userId = owner?.userId;
  if (cache == null || userId == null) {
    return guardRequest(() async => CachedList(parseList(await fetch(), parse)));
  }
  return guardRequest(() async {
    final result = await cache.networkFirst(
      ownerId: userId,
      key: key,
      fetch: fetch,
      parse: (json) => parseList(json, parse),
    );
    return CachedList(result.data, savedAt: result.savedAt);
  });
}

class MaterialRepositoryImpl implements MaterialRepository {
  static const String cacheKey = 'materials';

  final MarketplaceRemoteDataSource remote;
  final ResponseCache? cache;
  final SessionOwner? owner;

  MaterialRepositoryImpl(this.remote, {this.cache, this.owner});

  @override
  Future<List<MaterialEntity>> getMaterials() async {
    if (cache == null) return guardRequest(remote.getMaterials);
    final cached = await getMaterialsCached();
    return cached.items;
  }

  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() => _cachedList(
        cache: cache,
        owner: owner,
        key: cacheKey,
        fetch: remote.getMaterialsJson,
        parse: materialFromJson,
      );

  @override
  Future<MaterialEntity> createListing(
    NewListingData data,
  ) =>
      guardRequest(() async {
        final imageUrls = <String>[];

        for (final image in data.images) {
          imageUrls.add(
            await remote.uploadImage(
              bytes: image.bytes,
              filename: image.filename,
            ),
          );
        }

        final material = await remote.createMaterial({...newListingToJson(data), 'imageUrls': imageUrls});

        if (cache != null) unawaited(getMaterialsCached().then((_) {}, onError: (_) {}));
        return material;
      });
}

class WishlistRepositoryImpl implements WishlistRepository {
  static const String cacheKey = 'wishlist';

  final MarketplaceRemoteDataSource remote;
  final ResponseCache? cache;
  final SessionOwner? owner;

  WishlistRepositoryImpl(this.remote, {this.cache, this.owner});

  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() => _cachedList(
        cache: cache,
        owner: owner,
        key: cacheKey,
        fetch: remote.getWishlistJson,
        parse: wishlistItemFromJson,
      );

  @override
  Future<WishlistItemEntity> add(
    String materialId,
  ) async {
    final item = await guardRequest(
      () => remote.addToWishlist(materialId),
    );
    _refreshCopy();
    return item;
  }

  @override
  Future<void> remove(
    String wishlistItemId,
  ) async {
    await guardRequest(
      () => remote.removeFromWishlist(wishlistItemId),
    );
    _refreshCopy();
  }

  void _refreshCopy() {
    if (cache == null) return;
    unawaited(getWishlist().then((_) {}, onError: (_) {}));
  }
}

class ChatRepositoryImpl implements ChatRepository {
  final MarketplaceRemoteDataSource remote;
  final ResponseCache? cache;
  final SessionOwner? owner;

  ChatRepositoryImpl(this.remote, {this.cache, this.owner});

  @override
  Future<List<ChatRoomEntity>> getChatRooms() async {
    final cached = await getChatRoomsCached();
    return cached.items;
  }

  @override
  Future<CachedList<ChatRoomEntity>> getChatRoomsCached() => _cachedList(
        cache: cache,
        owner: owner,
        key: 'chat_rooms',
        fetch: remote.getChatRoomsJson,
        parse: chatRoomFromJson,
      );

  @override
  Future<ChatRoomEntity> openChatRoom(
    String materialId,
  ) =>
      guardRequest(
        () => remote.openChatRoom(materialId),
      );

  @override
  Future<List<MessageEntity>> getMessages(
    String chatRoomId,
  ) async {
    final cached = await getMessagesCached(chatRoomId);
    return cached.items;
  }

  @override
  Future<CachedList<MessageEntity>> getMessagesCached(String chatRoomId) => _cachedList(
        cache: cache,
        owner: owner,
        key: 'messages:$chatRoomId',
        fetch: () => remote.getMessagesJson(chatRoomId),
        parse: messageFromJson,
      );

  @override
  Future<MessageEntity> sendMessage(
    String chatRoomId,
    String content, {
    String? id,
    DateTime? clientCreatedAt,
  }) =>
      guardRequest(
        () => remote.sendMessage(
          chatRoomId,
          content,
          id: id,
          clientCreatedAt: clientCreatedAt,
        ),
      );

  @override
  Future<void> markRead(
    String chatRoomId,
  ) =>
      guardRequest(
        () => remote.markChatRead(chatRoomId),
      );
}

class ExchangeRepositoryImpl implements ExchangeRepository {
  final MarketplaceRemoteDataSource remote;

  ExchangeRepositoryImpl(this.remote);

  @override
  Future<List<ExchangeEntity>> getExchanges() =>
      guardRequest(
        remote.getExchanges,
      );

  @override
  Future<ExchangeEntity> placeOrder(
    String materialId,
  ) =>
      guardRequest(
        () => remote.placeOrder(materialId),
      );

  @override
  Future<ExchangeEntity> complete(
    String exchangeId, {
    MaterialConditionEnum? receivedCondition,
  }) =>
      guardRequest(
        () => remote.completeExchange(
          exchangeId,
          receivedCondition: receivedCondition?.name,
        ),
      );

  @override
  Future<ExchangeEntity> cancel(
    String exchangeId,
  ) =>
      guardRequest(
        () => remote.cancelExchange(exchangeId),
      );

  @override
  Future<void> rate(
    NewRating rating,
  ) =>
      guardRequest(
        () => remote.createRating(newRatingToJson(rating)),
      );
}

class RatingRepositoryImpl implements RatingRepository {
  final MarketplaceRemoteDataSource remote;

  RatingRepositoryImpl(this.remote);

  @override
  Future<List<RatingEntity>> getRatingsForUser(
    String userId,
  ) =>
      guardRequest(
        () => remote.getRatingsForUser(userId),
      );
}

class NotificationRepositoryImpl
    implements NotificationRepository {
  static const String cacheKey = 'notifications';

  final MarketplaceRemoteDataSource remote;
  final ResponseCache? cache;
  final SessionOwner? owner;

  NotificationRepositoryImpl(this.remote, {this.cache, this.owner});

  @override
  Future<CachedList<NotificationEntity>> getNotifications() => _cachedList(
        cache: cache,
        owner: owner,
        key: cacheKey,
        fetch: remote.getNotificationsJson,
        parse: notificationFromJson,
      );

  @override
  Future<void> markOpened(
    String notificationId,
  ) async {
    await guardRequest(
      () => remote.markNotificationOpened(notificationId),
    );
    // The saved copy should not bring the unread dot back after a restart.
    if (cache != null) unawaited(getNotifications().then((_) {}, onError: (_) {}));
  }
}
