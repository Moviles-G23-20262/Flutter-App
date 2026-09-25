import 'user.dart';
import 'material.dart';

class ChatRoom {
  final String id;
  final String materialId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final User? buyer;
  final MaterialEntity? material;
  final User? seller;
  final List<Message>? messages;

  ChatRoom({
    required this.id,
    required this.materialId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    this.buyer,
    this.material,
    this.seller,
    this.messages,
  });
}

class Message {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final User? sender;

  Message({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.sender,
  });
}