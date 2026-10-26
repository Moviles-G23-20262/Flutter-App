import 'package:flutter/foundation.dart';

/// What other users may see about someone: the seller of a listing, the other
/// side of a chat… (no email, no account details).
@immutable
class UserSummary {
  final String id;
  final String fullName;
  final String major;
  final String? faculty;

  /// Average rating in `[0.0, 5.0]`.
  final double rating;

  const UserSummary({
    required this.id,
    required this.fullName,
    required this.major,
    this.faculty,
    required this.rating,
  });

  /// Up to two uppercase initials, e.g. `'Maria Santos'` → `'MS'`.
  String get initials {
    final letters = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    return letters.join();
  }

  @override
  bool operator ==(Object other) => other is UserSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
