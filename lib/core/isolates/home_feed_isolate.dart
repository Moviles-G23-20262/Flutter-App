import 'package:flutter/foundation.dart';

import '../../model/entities/material_entity.dart';
import '../../model/entities/user_summary.dart';

/// Input row passed across the `compute()` isolate boundary (plain immutable data).
class HomeSellerInput {
  final String id;
  final String fullName;
  final String major;
  final double rating;
  final String categoryName;

  const HomeSellerInput({
    required this.id,
    required this.fullName,
    required this.major,
    required this.rating,
    required this.categoryName,
  });
}

/// One ranked featured seller computed off the UI thread.
class ComputedFeaturedSeller {
  final UserSummary seller;
  final int items;

  const ComputedFeaturedSeller(this.seller, this.items);
}

/// Output of the Home feed background isolate calculation.
class HomeFeedProjection {
  final List<ComputedFeaturedSeller> featuredSellers;
  final Map<String, int> categoryCounts;

  const HomeFeedProjection({
    required this.featuredSellers,
    required this.categoryCounts,
  });

  static const empty = HomeFeedProjection(featuredSellers: [], categoryCounts: {});
}

/// Pure top-level worker executed inside Flutter's `compute()` background isolate.
/// Groups available listings by seller and category in a single pass and returns the top 4 sellers.
HomeFeedProjection _computeHomeFeedProjectionWorker(List<HomeSellerInput> inputs) {
  final countBySeller = <String, int>{};
  final metaBySeller = <String, HomeSellerInput>{};
  final categoryCounts = <String, int>{};

  for (final item in inputs) {
    categoryCounts[item.categoryName] = (categoryCounts[item.categoryName] ?? 0) + 1;
    if (item.id.isEmpty) continue;
    countBySeller[item.id] = (countBySeller[item.id] ?? 0) + 1;
    metaBySeller.putIfAbsent(item.id, () => item);
  }

  final ranked = <ComputedFeaturedSeller>[
    for (final entry in countBySeller.entries)
      ComputedFeaturedSeller(
        UserSummary(
          id: metaBySeller[entry.key]!.id,
          fullName: metaBySeller[entry.key]!.fullName,
          major: metaBySeller[entry.key]!.major,
          rating: metaBySeller[entry.key]!.rating,
        ),
        entry.value,
      ),
  ]..sort((a, b) {
      final byItems = b.items.compareTo(a.items);
      return byItems != 0 ? byItems : b.seller.rating.compareTo(a.seller.rating);
    });

  return HomeFeedProjection(
    featuredSellers: List.unmodifiable(ranked.take(4)),
    categoryCounts: Map.unmodifiable(categoryCounts),
  );
}

/// Computes Home's Featured Sellers and category counts off the main UI isolate using Flutter's
/// `compute()` worker (Sprint 3 multi-threading — Sabrina Noguera).
Future<HomeFeedProjection> computeHomeFeedProjection(
  List<MaterialEntity> available, {
  bool forceIsolate = false,
}) {
  final inputs = [
    for (final m in available)
      HomeSellerInput(
        id: m.seller?.id ?? '',
        fullName: m.seller?.fullName ?? '',
        major: m.seller?.major ?? '',
        rating: m.seller?.rating ?? 0,
        categoryName: m.category.displayName,
      ),
  ];
  // Use Flutter's compute() background isolate for larger catalogs (or when forced in tests).
  if (forceIsolate || inputs.length >= 25) {
    return compute(_computeHomeFeedProjectionWorker, inputs);
  }
  return Future.value(_computeHomeFeedProjectionWorker(inputs));
}
