import 'package:flutter/foundation.dart';
import 'material_entity.dart';

enum NotificationTypeEnum {
  /// A new listing matched something the user was looking for.
  SMART_MATCH,
  OTHER;

  String get displayName {
    switch (this) {
      case NotificationTypeEnum.SMART_MATCH:
        return 'New match for you';
      case NotificationTypeEnum.OTHER:
        return 'Notification';
    }
  }
}

@immutable
class NotificationEntity {
  final String id;
  final String userId;
  final String? materialId;
  final NotificationTypeEnum type;
  final DateTime sentAt;

  /// `null` until the user opens it.
  final DateTime? openedAt;
  final MaterialEntity? material;

  const NotificationEntity({
    required this.id,
    required this.userId,
    this.materialId,
    required this.type,
    required this.sentAt,
    this.openedAt,
    this.material,
  });

  bool get isUnread => openedAt == null;

  NotificationEntity markOpened(DateTime when) => NotificationEntity(
        id: id,
        userId: userId,
        materialId: materialId,
        type: type,
        sentAt: sentAt,
        openedAt: when,
        material: material,
      );

  @override
  bool operator ==(Object other) => other is NotificationEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
