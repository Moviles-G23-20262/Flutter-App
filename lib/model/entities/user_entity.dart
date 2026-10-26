import 'package:flutter/foundation.dart';

// ──────────────────────────────────────────────────────────────────────────────
// UserEntity
// ──────────────────────────────────────────────────────────────────────────────

/// Domain entity representing a Campus Swap user account.
///
/// Maps 1-to-1 with the Prisma `User` model. Immutable by design;
/// use [copyWith] to produce modified copies.
@immutable
class UserEntity {
  /// Unique identifier (UUID).
  final String id;

  /// Verified university e-mail address.
  final String email;

  /// Display name as entered during registration.
  final String fullName;

  /// Academic major (e.g. `'Computer Science'`).
  final String major;

  /// Faculty / school the user belongs to. May be `null`.
  final String? faculty;

  /// Aggregate seller rating in the range `[0.0, 5.0]`.
  final double rating;

  /// Timestamp when the account was created.
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.major,
    this.faculty,
    required this.rating,
    required this.createdAt,
  });

  // ── Convenience getters ───────────────────────────────────────────────────────

  /// Returns up to two uppercase initials derived from [fullName].
  ///
  /// Examples:
  /// - `'María García'` → `'MG'`
  /// - `'John'` → `'J'`
  /// - `'Anne Marie Dupont'` → `'AM'`
  String get initials {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    return letters.join();
  }

  // ── copyWith ─────────────────────────────────────────────────────────────────

  /// Returns a copy of this entity with the given fields replaced.
  UserEntity copyWith({
    String? id,
    String? email,
    String? fullName,
    String? major,
    Object? faculty = _sentinel,
    double? rating,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id:        id        ?? this.id,
      email:     email     ?? this.email,
      fullName:  fullName  ?? this.fullName,
      major:     major     ?? this.major,
      faculty:   faculty   == _sentinel ? this.faculty : faculty as String?,
      rating:    rating    ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserEntity(id: $id, fullName: $fullName, rating: $rating)';
}

/// Private sentinel used by [UserEntity.copyWith] to distinguish `null`
/// from "not provided".
const Object _sentinel = Object();
