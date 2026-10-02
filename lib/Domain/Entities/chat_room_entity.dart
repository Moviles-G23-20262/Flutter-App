import 'package:flutter/foundation.dart';
import 'material_entity.dart';
import 'user_summary.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ChatRoomEntity
// ──────────────────────────────────────────────────────────────────────────────

/// Domain entity representing a private chat channel between a buyer and a
/// seller negotiating the purchase of a specific [MaterialEntity].
@immutable
class ChatRoomEntity {
  /// Unique identifier (UUID).
  final String id;

  /// ID of the [MaterialEntity] that prompted this conversation.
  final String materialId;

  /// ID of the [UserEntity] who initiated the chat (the buyer).
  final String buyerId;

  /// ID of the [UserEntity] who listed the material (the seller).
  final String sellerId;

  /// Timestamp when the chat room was created.
  final DateTime createdAt;

  /// The listing being discussed.
  final MaterialEntity? material;

  final UserSummary? buyer;
  final UserSummary? seller;

  /// Most recent message, if any (conversation list only).
  final MessageEntity? lastMessage;

  /// Messages from the other person the caller has not read yet.
  final int unreadCount;

  const ChatRoomEntity({
    required this.id,
    required this.materialId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    this.material,
    this.buyer,
    this.seller,
    this.lastMessage,
    this.unreadCount = 0,
  });

  /// The person on the other side of the conversation, from [myId]'s point of view.
  UserSummary? otherParty(String myId) => myId == buyerId ? seller : buyer;

  /// When the conversation last changed: the last message, else its creation.
  DateTime get lastActivity => lastMessage?.createdAt ?? createdAt;

  // ── copyWith ─────────────────────────────────────────────────────────────────

  /// Returns a copy of this entity with the given fields replaced.
  ChatRoomEntity copyWith({
    String? id,
    String? materialId,
    String? buyerId,
    String? sellerId,
    DateTime? createdAt,
  }) {
    return ChatRoomEntity(
      id:         id         ?? this.id,
      materialId: materialId ?? this.materialId,
      buyerId:    buyerId    ?? this.buyerId,
      sellerId:   sellerId   ?? this.sellerId,
      createdAt:  createdAt  ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRoomEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChatRoomEntity(id: $id, materialId: $materialId)';
}

// ──────────────────────────────────────────────────────────────────────────────
// MessageEntity
// ──────────────────────────────────────────────────────────────────────────────

/// Domain entity representing a single message inside a [ChatRoomEntity].
@immutable
class MessageEntity {
  /// Unique identifier (UUID).
  final String id;

  /// ID of the [ChatRoomEntity] this message belongs to.
  final String chatRoomId;

  /// ID of the [UserEntity] who sent this message.
  final String senderId;

  /// Plain-text message body.
  final String content;

  /// Whether the recipient has read this message.
  final bool isRead;

  /// Timestamp when the message was created / sent.
  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  // ── copyWith ─────────────────────────────────────────────────────────────────

  /// Returns a copy of this entity with the given fields replaced.
  MessageEntity copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return MessageEntity(
      id:         id         ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId:   senderId   ?? this.senderId,
      content:    content    ?? this.content,
      isRead:     isRead     ?? this.isRead,
      createdAt:  createdAt  ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MessageEntity(id: $id, chatRoomId: $chatRoomId, isRead: $isRead)';
}
