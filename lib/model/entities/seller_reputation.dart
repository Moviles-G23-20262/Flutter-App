import 'package:flutter/foundation.dart';

/// Aggregated conversion & speed metrics for one reputation bucket in BQ 17
/// (`GET /analytics/seller-reputation/`).
@immutable
class ReputationTierStats {
  final String group;
  final String label;
  final int sellers;
  final int listings;
  final int contacted;
  final double contactRate;
  final double buyersPerListing;
  final int sold;
  final double saleRate;
  final double? medianDaysToSell;

  const ReputationTierStats({
    required this.group,
    required this.label,
    required this.sellers,
    required this.listings,
    required this.contacted,
    required this.contactRate,
    required this.buyersPerListing,
    required this.sold,
    required this.saleRate,
    required this.medianDaysToSell,
  });

  /// Contact rate expressed as an integer percentage (`0`–`100`).
  int get contactRatePercent => (contactRate * 100).round();

  /// Sale rate expressed as an integer percentage (`0`–`100`).
  int get saleRatePercent => (saleRate * 100).round();
}

/// BQ 17 insight: do listings from sellers with higher ratings and more reviews
/// get more buyer interest and sell faster than those from new or low-rated sellers?
@immutable
class SellerReputationInsight {
  final int listingsTotal;
  final int sellersWithReviews;
  final List<ReputationTierStats> byStars;
  final List<ReputationTierStats> byReviewCount;

  /// Non-null when this insight came from the local SQLite cache while offline.
  final DateTime? savedAt;

  const SellerReputationInsight({
    required this.listingsTotal,
    required this.sellersWithReviews,
    required this.byStars,
    required this.byReviewCount,
    this.savedAt,
  });

  bool get isEmpty => listingsTotal == 0 || (byStars.isEmpty && byReviewCount.isEmpty);

  SellerReputationInsight copyWith({DateTime? savedAt}) => SellerReputationInsight(
        listingsTotal: listingsTotal,
        sellersWithReviews: sellersWithReviews,
        byStars: byStars,
        byReviewCount: byReviewCount,
        savedAt: savedAt ?? this.savedAt,
      );

  /// Maps a seller's average rating and review count to the backend star-tier key.
  static String starGroupKey({required double averageRating, required int reviewCount}) {
    if (reviewCount <= 0 || averageRating <= 0) return 'no_reviews';
    if (averageRating < 3.0) return 'below_3';
    if (averageRating < 4.0) return '3_to_4';
    if (averageRating < 4.5) return '4_to_4_5';
    return '4_5_and_up';
  }

  /// Maps a seller's review count to the backend review-volume key.
  static String reviewGroupKey(int reviewCount) {
    if (reviewCount <= 0) return 'none';
    if (reviewCount <= 2) return '1_2';
    if (reviewCount <= 5) return '3_5';
    return '6_plus';
  }

  ReputationTierStats? starTierFor({required double averageRating, required int reviewCount}) {
    final key = starGroupKey(averageRating: averageRating, reviewCount: reviewCount);
    for (final tier in byStars) {
      if (tier.group == key) return tier;
    }
    return null;
  }

  ReputationTierStats? reviewTierFor(int reviewCount) {
    final key = reviewGroupKey(reviewCount);
    for (final tier in byReviewCount) {
      if (tier.group == key) return tier;
    }
    return null;
  }

  /// Baseline tier (`no_reviews`) to compare rated sellers against newcomers.
  ReputationTierStats? get noReviewsBaseline {
    for (final tier in byStars) {
      if (tier.group == 'no_reviews') return tier;
    }
    return null;
  }
}
