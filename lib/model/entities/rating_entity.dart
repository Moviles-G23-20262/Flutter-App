import 'package:flutter/foundation.dart';
import 'user_summary.dart';


@immutable
class RatingEntity {
  final String id;
  final String exchangeId;
  final String raterId;
  final String ratedId;
  final int stars;
  final List<String> tags;
  final String? review;
  final DateTime createdAt;
  final UserSummary? rater;

  const RatingEntity({
    required this.id,
    required this.exchangeId,
    required this.raterId,
    required this.ratedId,
    required this.stars,
    this.tags = const [],
    this.review,
    required this.createdAt,
    this.rater,
  });
}