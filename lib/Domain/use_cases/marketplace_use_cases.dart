import '../Entities/chat_room_entity.dart';
import '../Entities/exchange_entity.dart';
import '../Entities/material_entity.dart';
import '../Entities/new_listing_data.dart';
import '../Entities/notification_entity.dart';
import '../Entities/wishlist_item_entity.dart';
import '../exceptions/data_exceptions.dart';
import '../repositories/marketplace_repositories.dart';

class GetMaterialsUseCase {
  final MaterialRepository repository;
  GetMaterialsUseCase(this.repository);

  Future<List<MaterialEntity>> execute() => repository.getMaterials();
}

class CreateListingUseCase {
  final MaterialRepository repository;
  CreateListingUseCase(this.repository);

  Future<MaterialEntity> execute(NewListingData data) {
    if (data.title.trim().length < 2) throw const DataException('Give your listing a title.');
    if (data.description.trim().isEmpty) throw const DataException('Describe your item.');
    if (data.price <= 0) throw const DataException('Enter a price greater than zero.');
    return repository.createListing(data);
  }
}

class GetWishlistUseCase {
  final WishlistRepository repository;
  GetWishlistUseCase(this.repository);

  Future<List<WishlistItemEntity>> execute() => repository.getWishlist();
}

class AddToWishlistUseCase {
  final WishlistRepository repository;
  AddToWishlistUseCase(this.repository);

  Future<WishlistItemEntity> execute(String materialId) => repository.add(materialId);
}

class RemoveFromWishlistUseCase {
  final WishlistRepository repository;
  RemoveFromWishlistUseCase(this.repository);

  Future<void> execute(String wishlistItemId) => repository.remove(wishlistItemId);
}

class GetChatRoomsUseCase {
  final ChatRepository repository;
  GetChatRoomsUseCase(this.repository);

  Future<List<ChatRoomEntity>> execute() => repository.getChatRooms();
}

class OpenChatRoomUseCase {
  final ChatRepository repository;
  OpenChatRoomUseCase(this.repository);

  Future<ChatRoomEntity> execute(String materialId) => repository.openChatRoom(materialId);
}

class GetMessagesUseCase {
  final ChatRepository repository;
  GetMessagesUseCase(this.repository);

  Future<List<MessageEntity>> execute(String chatRoomId) => repository.getMessages(chatRoomId);
}

class SendMessageUseCase {
  final ChatRepository repository;
  SendMessageUseCase(this.repository);

  Future<MessageEntity> execute(String chatRoomId, String content) {
    final text = content.trim();
    if (text.isEmpty) throw const DataException('Write a message first.');
    if (text.length > 2000) throw const DataException('Messages can have at most 2000 characters.');
    return repository.sendMessage(chatRoomId, text);
  }
}

class MarkChatReadUseCase {
  final ChatRepository repository;
  MarkChatReadUseCase(this.repository);

  Future<void> execute(String chatRoomId) => repository.markRead(chatRoomId);
}

class GetExchangesUseCase {
  final ExchangeRepository repository;
  GetExchangesUseCase(this.repository);

  Future<List<ExchangeEntity>> execute() => repository.getExchanges();
}

class PlaceOrderUseCase {
  final ExchangeRepository repository;
  PlaceOrderUseCase(this.repository);

  Future<ExchangeEntity> execute(MaterialEntity material, {required String buyerId}) {
    if (material.sellerId == buyerId) throw const DataException('This is your own listing.');
    if (!material.isAvailable) throw const DataException('This item is no longer available.');
    return repository.placeOrder(material.id);
  }
}

class CompleteExchangeUseCase {
  final ExchangeRepository repository;
  CompleteExchangeUseCase(this.repository);

  Future<ExchangeEntity> execute(ExchangeEntity exchange, {MaterialConditionEnum? receivedCondition}) {
    if (!exchange.isPending) throw const DataException('This exchange is already closed.');
    return repository.complete(exchange.id, receivedCondition: receivedCondition);
  }
}

class CancelExchangeUseCase {
  final ExchangeRepository repository;
  CancelExchangeUseCase(this.repository);

  Future<ExchangeEntity> execute(ExchangeEntity exchange) {
    if (!exchange.isPending) throw const DataException('This exchange is already closed.');
    return repository.cancel(exchange.id);
  }
}

class RateUserUseCase {
  final ExchangeRepository repository;
  RateUserUseCase(this.repository);

  Future<void> execute(NewRating rating) {
    if (rating.stars < 1 || rating.stars > 5) throw const DataException('Pick from 1 to 5 stars.');
    final review = rating.review?.trim();
    if (review != null && review.length > 500) {
      throw const DataException('Reviews can have at most 500 characters.');
    }
    return repository.rate(NewRating(
      exchangeId: rating.exchangeId,
      ratedId: rating.ratedId,
      stars: rating.stars,
      tags: rating.tags,
      review: review == null || review.isEmpty ? null : review,
    ));
  }
}

class GetNotificationsUseCase {
  final NotificationRepository repository;
  GetNotificationsUseCase(this.repository);

  Future<List<NotificationEntity>> execute() => repository.getNotifications();
}

class MarkNotificationOpenedUseCase {
  final NotificationRepository repository;
  MarkNotificationOpenedUseCase(this.repository);

  Future<void> execute(String notificationId) => repository.markOpened(notificationId);
}
