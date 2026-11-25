import 'dart:developer' as developer;
import 'dart:isolate';

import '../../model/entities/material_entity.dart';
import '../../model/entities/rating_entity.dart';
import '../../model/entities/seller_profile_entity.dart';

/// Input payload transferred to the background isolate to summarize a seller's profile.
class SellerProfileAggregationInput {
  final List<RatingEntity> reviews;
  final List<MaterialEntity> sellerListings;
  final double fallbackRating;
  final int maxTopTags;

  const SellerProfileAggregationInput({
    required this.reviews,
    required this.sellerListings,
    required this.fallbackRating,
    this.maxTopTags = 3,
  });
}

/// Runs the single-pass Seller Profile aggregation off the UI isolate via [Isolate.run].
///
/// Keeps star histogram building, tag frequency counting, listing status partitioning,
/// and review sorting off the main thread so scrolling and transitions stay within the
/// 16.6 ms frame budget even for high-volume sellers.
Future<SellerProfileSummary> aggregateSellerProfileInIsolate(
  SellerProfileAggregationInput input,
) =>
    Isolate.run(() => aggregateSellerProfileSync(input));

/// Single-pass O(R + L) aggregator (MO6) with `dart:developer` Timeline markers.
///
/// Exposed synchronously as well so micro-benchmarks and unit tests can measure
/// exact execution cost alongside the isolate path.
SellerProfileSummary aggregateSellerProfileSync(SellerProfileAggregationInput input) {
  developer.Timeline.startSync('SellerProfile.aggregate');
  try {
    final reviews = input.reviews;
    final listings = input.sellerListings;

    // 1. Single pass over reviews: sum stars, fill 5-slot histogram, tally tag counts.
    final starCounts = List<int>.filled(5, 0);
    final tagCounts = <String, int>{};
    var starSum = 0;

    for (var i = 0; i < reviews.length; i++) {
      final r = reviews[i];
      final clampedStars = r.stars.clamp(1, 5);
      starSum += clampedStars;
      starCounts[clampedStars - 1]++;
      final tags = r.tags;
      for (var t = 0; t < tags.length; t++) {
        final normalized = tags[t].trim();
        if (normalized.isEmpty) continue;
        tagCounts[normalized] = (tagCounts[normalized] ?? 0) + 1;
      }
    }

    final reviewCount = reviews.length;
    final averageRating = reviewCount > 0 ? starSum / reviewCount : input.fallbackRating;

    // 5 stars down to 1 star.
    final starDistribution = List<StarBucketCount>.generate(
      5,
      (index) {
        final starLevel = 5 - index;
        final count = starCounts[starLevel - 1];
        return StarBucketCount(
          stars: starLevel,
          count: count,
          fraction: reviewCount > 0 ? count / reviewCount : 0.0,
        );
      },
      growable: false,
    );

    // Top N tags by count descending, then alphabetically for stable order.
    final sortedTags = tagCounts.entries.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final limit = sortedTags.length < input.maxTopTags ? sortedTags.length : input.maxTopTags;
    final topTags = [
      for (var i = 0; i < limit; i++) TagFrequency(tag: sortedTags[i].key, count: sortedTags[i].value),
    ];

    // Sort reviews newest first without mutating caller's list.
    final sortedReviews = List<RatingEntity>.of(reviews, growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 2. Single pass over seller's listings: count available vs sold & collect available items.
    var activeCount = 0;
    var soldCount = 0;
    final availableListings = <MaterialEntity>[];
    for (var i = 0; i < listings.length; i++) {
      final item = listings[i];
      if (item.isAvailable) {
        activeCount++;
        availableListings.add(item);
      } else if (item.status == MaterialStatusEnum.SOLD) {
        soldCount++;
      }
    }
    availableListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SellerProfileSummary(
      averageRating: averageRating,
      reviewCount: reviewCount,
      starDistribution: starDistribution,
      topTags: topTags,
      activeListingsCount: activeCount,
      soldListingsCount: soldCount,
      totalListingsCount: listings.length,
      availableListings: List.unmodifiable(availableListings),
      reviews: List.unmodifiable(sortedReviews),
    );
  } finally {
    developer.Timeline.finishSync();
  }
}
