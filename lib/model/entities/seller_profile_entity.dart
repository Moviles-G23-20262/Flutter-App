import 'package:flutter/foundation.dart';

import 'material_entity.dart';
import 'rating_entity.dart';
import 'major_activity.dart';
import 'seller_reputation.dart';
import 'user_summary.dart';

/// One row of the 5-to-1 star distribution bar chart on the Seller Profile screen.
@immutable
class StarBucketCount {
  final int stars;
  final int count;
  final double fraction;

  const StarBucketCount({
    required this.stars,
    required this.count,
    required this.fraction,
  });
}

/// Frequency of a buyer feedback tag (e.g. `"Punctual"`, `"As described"`).
@immutable
class TagFrequency {
  final String tag;
  final int count;

  const TagFrequency({required this.tag, required this.count});
}

/// Aggregated stats produced in a background isolate from a seller's ratings and listings.
@immutable
class SellerProfileSummary {
  final double averageRating;
  final int reviewCount;

  /// Always 5 entries ordered from 5 stars down to 1 star.
  final List<StarBucketCount> starDistribution;

  /// Top 3 most frequent review tags ("Buyers say").
  final List<TagFrequency> topTags;

  final int activeListingsCount;
  final int soldListingsCount;
  final int totalListingsCount;

  /// Available listings currently for sale by this seller.
  final List<MaterialEntity> availableListings;

  /// Reviews ordered newest first.
  final List<RatingEntity> reviews;

  const SellerProfileSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.starDistribution,
    required this.topTags,
    required this.activeListingsCount,
    required this.soldListingsCount,
    required this.totalListingsCount,
    required this.availableListings,
    required this.reviews,
  });
}

/// Complete payload rendered by `SellerProfileScreen`.
@immutable
class SellerProfileData {
  final UserSummary seller;
  final SellerProfileSummary summary;

  /// Optional campus-wide BQ 17 benchmark (`GET /analytics/seller-reputation/`).
  final SellerReputationInsight? reputation;

  /// Optional campus-wide BQ 18 benchmark (GET /analytics/major-activity/).
  final MajorActivityInsight? majorActivity;

  /// Non-null when the profile was served from the local SQLite `seller_profiles` table offline.
  final DateTime? savedAt;

  /// True when answered directly from the in-memory LRU cache (0 network / 0 SQLite reads).
  final bool fromMemoryCache;

  const SellerProfileData({
    required this.seller,
    required this.summary,
    this.reputation,
    this.majorActivity,
    this.savedAt,
    this.fromMemoryCache = false,
  });

  bool get isOfflineCopy => savedAt != null;

  SellerProfileData copyWith({
    UserSummary? seller,
    SellerProfileSummary? summary,
    SellerReputationInsight? reputation,
    MajorActivityInsight? majorActivity,
    DateTime? savedAt,
    bool clearSavedAt = false,
    bool? fromMemoryCache,
  }) =>
      SellerProfileData(
        seller: seller ?? this.seller,
        summary: summary ?? this.summary,
        reputation: reputation ?? this.reputation,
        majorActivity: majorActivity ?? this.majorActivity,
        savedAt: clearSavedAt ? null : (savedAt ?? this.savedAt),
        fromMemoryCache: fromMemoryCache ?? this.fromMemoryCache,
      );
}
