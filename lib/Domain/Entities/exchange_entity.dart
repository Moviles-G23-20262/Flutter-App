import 'package:flutter/foundation.dart';
import 'material_entity.dart';
import 'user_summary.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ExchangeEntity
// ──────────────────────────────────────────────────────────────────────────────

/// Domain entity representing a recorded transaction between a buyer and a
/// seller for a specific [MaterialEntity].
///
/// When [meetingPointId], [lat], and [lng] are provided, the exchange includes
/// a physical in-campus meeting location.
@immutable
class ExchangeEntity {
  /// Unique identifier (UUID).
  final String id;

  /// ID of the [MaterialEntity] being exchanged.
  final String materialId;

  /// ID of the [UserEntity] purchasing the material.
  final String buyerId;

  /// ID of the [UserEntity] selling the material.
  final String sellerId;

  /// Agreed transaction price at the time of the exchange.
  final double price;

  /// Timestamp when the exchange was finalised. `null` if still pending.
  final DateTime? completedAt;

  /// Optional ID referencing a known campus meeting point (e.g. a building).
  final String? meetingPointId;

  /// Latitude of the agreed meeting location. `null` if not specified.
  final double? lat;

  /// Longitude of the agreed meeting location. `null` if not specified.
  final double? lng;

  /// The item and the two people, when the API included them.
  final MaterialEntity? material;
  final UserSummary? buyer;
  final UserSummary? seller;

  const ExchangeEntity({
    required this.id,
    required this.materialId,
    required this.buyerId,
    required this.sellerId,
    required this.price,
    this.completedAt,
    this.meetingPointId,
    this.lat,
    this.lng,
    this.material,
    this.buyer,
    this.seller,
  });

  // ── Convenience getters ───────────────────────────────────────────────────────

  /// Returns `true` when [completedAt] has been set.
  bool get isCompleted => completedAt != null;

  /// Returns `true` when a geo-coordinate meeting point has been specified.
  bool get hasMeetingLocation => lat != null && lng != null;

  // ── copyWith ─────────────────────────────────────────────────────────────────

  /// Returns a copy of this entity with the given fields replaced.
  ExchangeEntity copyWith({
    String? id,
    String? materialId,
    String? buyerId,
    String? sellerId,
    double? price,
    Object? completedAt    = _sentinel,
    Object? meetingPointId = _sentinel,
    Object? lat            = _sentinel,
    Object? lng            = _sentinel,
  }) {
    return ExchangeEntity(
      id:             id             ?? this.id,
      materialId:     materialId     ?? this.materialId,
      buyerId:        buyerId        ?? this.buyerId,
      sellerId:       sellerId       ?? this.sellerId,
      price:          price          ?? this.price,
      completedAt:    completedAt    == _sentinel ? this.completedAt    : completedAt    as DateTime?,
      meetingPointId: meetingPointId == _sentinel ? this.meetingPointId : meetingPointId as String?,
      lat:            lat            == _sentinel ? this.lat            : lat            as double?,
      lng:            lng            == _sentinel ? this.lng            : lng            as double?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ExchangeEntity(id: $id, materialId: $materialId, price: $price, '
      'isCompleted: $isCompleted)';
}

/// Private sentinel used by [ExchangeEntity.copyWith] to distinguish `null`
/// from "not provided".
const Object _sentinel = Object();
