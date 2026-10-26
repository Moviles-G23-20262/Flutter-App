import 'package:flutter/foundation.dart';
import 'user_summary.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────────────────────────────────────

/// Physical condition of the material being sold.
enum MaterialConditionEnum {
  /// Brand new, sealed/unused.
  NEW,

  /// Used but in near-perfect condition.
  LIKE_NEW,

  /// Normal wear and tear, fully functional.
  GOOD,

  /// Noticeable wear but still usable.
  FAIR;

  /// Human-readable label for display in the UI.
  String get displayName {
    switch (this) {
      case MaterialConditionEnum.NEW:
        return 'New';
      case MaterialConditionEnum.LIKE_NEW:
        return 'Like New';
      case MaterialConditionEnum.GOOD:
        return 'Good';
      case MaterialConditionEnum.FAIR:
        return 'Fair';
    }
  }
}

/// Availability status of the material listing.
enum MaterialStatusEnum {
  /// Visible and open to buyers.
  AVAILABLE,

  /// Temporarily held for a buyer.
  RESERVED,

  /// Transaction completed.
  SOLD;

  /// Human-readable label for display in the UI.
  String get displayName {
    switch (this) {
      case MaterialStatusEnum.AVAILABLE:
        return 'Available';
      case MaterialStatusEnum.RESERVED:
        return 'Reserved';
      case MaterialStatusEnum.SOLD:
        return 'Sold';
    }
  }
}

/// High-level category that groups marketplace listings.
enum MaterialCategoryEnum {
  /// Textbooks, notebooks, or printed materials.
  BOOKS,

  /// Scientific or graphing calculators.
  CALCULATORS,

  /// Lab coats, goggles, kits, etc.
  LAB_EQUIPMENT,

  /// Desks, chairs, shelving, etc.
  FURNITURE,

  /// Anything that does not fit above categories.
  OTHER;

  /// Human-readable label for display in the UI.
  String get displayName {
    switch (this) {
      case MaterialCategoryEnum.BOOKS:
        return 'Books';
      case MaterialCategoryEnum.CALCULATORS:
        return 'Calculators';
      case MaterialCategoryEnum.LAB_EQUIPMENT:
        return 'Lab Equipment';
      case MaterialCategoryEnum.FURNITURE:
        return 'Furniture';
      case MaterialCategoryEnum.OTHER:
        return 'Other';
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MaterialEntity
// ──────────────────────────────────────────────────────────────────────────────

/// Domain entity representing a single marketplace listing on Campus Swap.
///
/// Maps 1-to-1 with the Prisma `Material` model. Immutable by design;
/// use [copyWith] to produce modified copies.
@immutable
class MaterialEntity {
  /// Unique identifier (UUID).
  final String id;

  /// Short, descriptive title of the listing.
  final String title;

  /// Detailed description provided by the seller.
  final String description;

  /// Related course code (e.g. `CS-301`). May be `null` for general items.
  final String? courseCode;

  /// Asking price in the local currency.
  final double price;

  /// Physical condition of the item. Nullable for digital goods.
  final MaterialConditionEnum? condition;

  /// Current availability status of the listing.
  final MaterialStatusEnum status;

  /// Edition number (e.g. `"5th"`). Relevant mainly for books.
  final String? edition;

  /// Device model name (e.g. `"TI-84 Plus CE"`). Relevant for calculators.
  final String? model;

  /// Ordered list of remote image URLs for this listing.
  final List<String> imageUrls;

  /// ID of the [UserEntity] who posted this listing.
  final String sellerId;

  /// Public profile of the seller, when the API included it.
  final UserSummary? seller;

  /// Broad category this listing belongs to.
  final MaterialCategoryEnum category;

  /// Timestamp when the listing was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent update to the listing.
  final DateTime updatedAt;

  const MaterialEntity({
    required this.id,
    required this.title,
    required this.description,
    this.courseCode,
    required this.price,
    this.condition,
    required this.status,
    this.edition,
    this.model,
    required this.imageUrls,
    required this.sellerId,
    this.seller,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Convenience getters ───────────────────────────────────────────────────────

  /// Returns a human-readable condition label, or `'N/A'` if not set.
  String get conditionDisplayName =>
      condition?.displayName ?? 'N/A';

  /// Returns `true` when buyers can still purchase or reserve this listing.
  bool get isAvailable => status == MaterialStatusEnum.AVAILABLE;

  /// Returns the first image URL, or an empty string if there are no images.
  String get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  // ── copyWith ─────────────────────────────────────────────────────────────────

  /// Returns a copy of this entity with the given fields replaced.
  MaterialEntity copyWith({
    String? id,
    String? title,
    String? description,
    Object? courseCode = _sentinel,
    double? price,
    Object? condition = _sentinel,
    MaterialStatusEnum? status,
    Object? edition = _sentinel,
    Object? model = _sentinel,
    List<String>? imageUrls,
    String? sellerId,
    Object? seller = _sentinel,
    MaterialCategoryEnum? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialEntity(
      id:          id          ?? this.id,
      title:       title       ?? this.title,
      description: description ?? this.description,
      courseCode:  courseCode  == _sentinel ? this.courseCode  : courseCode as String?,
      price:       price       ?? this.price,
      condition:   condition   == _sentinel ? this.condition   : condition as MaterialConditionEnum?,
      status:      status      ?? this.status,
      edition:     edition     == _sentinel ? this.edition     : edition as String?,
      model:       model       == _sentinel ? this.model       : model as String?,
      imageUrls:   imageUrls   ?? this.imageUrls,
      sellerId:    sellerId    ?? this.sellerId,
      seller:      seller      == _sentinel ? this.seller : seller as UserSummary?,
      category:    category    ?? this.category,
      createdAt:   createdAt   ?? this.createdAt,
      updatedAt:   updatedAt   ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MaterialEntity(id: $id, title: $title, status: ${status.displayName})';
}

/// Private sentinel used by [MaterialEntity.copyWith] to distinguish `null`
/// from "not provided".
const Object _sentinel = Object();
