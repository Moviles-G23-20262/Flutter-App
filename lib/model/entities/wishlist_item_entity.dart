import 'package:flutter/foundation.dart';
import 'material_entity.dart';

/// A listing a user saved as a favorite.
@immutable
class WishlistItemEntity {
  final String id;
  final String userId;
  final String materialId;
  final MaterialEntity? material;
  final DateTime createdAt;

  const WishlistItemEntity({
    required this.id,
    required this.userId,
    required this.materialId,
    this.material,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) => other is WishlistItemEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
