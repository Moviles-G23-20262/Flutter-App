import 'package:flutter/foundation.dart';
import 'material_entity.dart';
import 'meetup_entities.dart';
import 'user_summary.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ExchangeEntity
// ──────────────────────────────────────────────────────────────────────────────

enum ExchangeStatusEnum {
  /// Ordered; buyer and seller still have to meet.
  PENDING,
  COMPLETED,
  CANCELLED;

  String get displayName {
    switch (this) {
      case ExchangeStatusEnum.PENDING:
        return 'Pending';
      case ExchangeStatusEnum.COMPLETED:
        return 'Completed';
      case ExchangeStatusEnum.CANCELLED:
        return 'Cancelled';
    }
  }
}

/// An order for a [MaterialEntity]: placed by the buyer, completed after they meet
/// on campus and the buyer checks the item, or cancelled by either side.
@immutable
class ExchangeEntity {
  /// Unique identifier (UUID).
  final String id;

  /// Sequential number shown to people, see [orderCode].
  final int orderNumber;

  /// ID of the [MaterialEntity] being exchanged.
  final String materialId;

  /// ID of the [UserEntity] purchasing the material.
  final String buyerId;

  /// ID of the [UserEntity] selling the material.
  final String sellerId;

  /// Listing price when the order was placed.
  final double price;

  final ExchangeStatusEnum status;

  /// When the order was placed.
  final DateTime? createdAt;

  /// When the buyer confirmed the exchange. `null` while pending or if cancelled.
  final DateTime? completedAt;

  /// The condition the buyer says they received.
  final MaterialConditionEnum? receivedCondition;

  /// The agreed campus meetup, once one was accepted in the chat.
  final String? meetingPointId;
  final MeetingPointEntity? meetingPoint;
  final DateTime? meetingStartsAt;
  final DateTime? meetingEndsAt;

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
    required this.orderNumber,
    required this.materialId,
    required this.buyerId,
    required this.sellerId,
    required this.price,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.receivedCondition,
    this.meetingPointId,
    this.meetingPoint,
    this.meetingStartsAt,
    this.meetingEndsAt,
    this.lat,
    this.lng,
    this.material,
    this.buyer,
    this.seller,
  });

  // ── Convenience getters ───────────────────────────────────────────────────────

  /// "CSW-1001".
  String get orderCode => 'CSW-$orderNumber';

  bool get isPending => status == ExchangeStatusEnum.PENDING;

  bool get isCompleted => status == ExchangeStatusEnum.COMPLETED;

  /// Returns `true` when a geo-coordinate meeting point has been specified.
  bool get hasMeetingLocation => lat != null && lng != null;

  /// The person on the other side, from [myId]'s point of view.
  UserSummary? otherParty(String myId) => myId == buyerId ? seller : buyer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ExchangeEntity(id: $id, order: $orderCode, materialId: $materialId, status: ${status.name})';
}

/// A rating one side of a completed exchange gives the other.
@immutable
class NewRating {
  final String exchangeId;
  final String ratedId;

  /// 1 to 5.
  final int stars;
  final List<String> tags;
  final String? review;

  const NewRating({
    required this.exchangeId,
    required this.ratedId,
    required this.stars,
    this.tags = const [],
    this.review,
  });
}
