import 'dart:isolate';
import 'dart:math' as math;

import '../../model/dto/dead_listings_model.dart';
import '../../model/entities/dead_listings_insight.dart';
import '../../model/entities/material_entity.dart';

/// Multi-threading worker (Dart [Isolate.run]) for BQ 10 Dead Listings & Price-Drop Advisor.
///
/// Offloads three CPU-bound steps off the UI thread so chart rendering, scrolling, and interactive
/// discount slider drags never drop frames:
/// 1. Parsing large BQ 10 JSON payloads ([parseDeadListingsInBackground]).
/// 2. Computing category price benchmarks, overlaying local/optimistic prices, scoring unsold
///    listing risk, and partitioning dismissed advisories ([analyzeSellerListingHealth]).
/// 3. Simulating "What-If" price-drop outcomes in real time ([simulatePriceDropInIsolate]).

/// Parses a decoded `/analytics/dead-listings/` map in a background isolate.
Future<DeadListingsModel> parseDeadListingsInBackground(Map<String, dynamic> rawJson) {
  return Isolate.run(
    () => DeadListingsModel.fromJson(rawJson),
    debugName: 'parse-dead-listings',
  );
}

/// Evaluates seller listings, applies category medians and local price overrides, matches cluster
/// patterns, separates dismissed items, and sorts highest risk first on a worker isolate.
Future<ListingHealthAnalysisResult> analyzeSellerListingHealth({
  required DeadListingsInsight report,
  required List<MaterialEntity> sellerListings,
  required List<MaterialEntity> allMarketplaceListings,
  required String sellerId,
  required int staleDays,
  required Set<String> dismissedIds,
  Map<String, double> localPriceOverrides = const {},
  DateTime? now,
}) {
  final referenceNow = now ?? DateTime.now().toUtc();
  final dismissedSnapshot = Set<String>.unmodifiable(dismissedIds);
  final overrideSnapshot = Map<String, double>.unmodifiable(localPriceOverrides);
  final sellerSnapshot = List<MaterialEntity>.unmodifiable(sellerListings);
  final marketSnapshot = List<MaterialEntity>.unmodifiable(allMarketplaceListings);

  return Isolate.run(
    () => _analyzeOnWorker(
      report: report,
      sellerListings: sellerSnapshot,
      allMarketplaceListings: marketSnapshot,
      sellerId: sellerId,
      staleDays: staleDays,
      dismissedIds: dismissedSnapshot,
      localPriceOverrides: overrideSnapshot,
      now: referenceNow,
    ),
    debugName: 'listing-health-analyze',
  );
}

/// Runs an interactive What-If price-drop risk simulation on a worker isolate.
Future<PriceDropSimulation> simulatePriceDropInIsolate({
  required SellerListingHealthItem item,
  required double newPrice,
  int staleDays = 14,
  double? baselineCategorySellDays,
}) {
  return Isolate.run(
    () => _simulatePriceDropWorker(
      item: item,
      newPrice: newPrice,
      staleDays: staleDays,
      baselineCategorySellDays: baselineCategorySellDays,
    ),
    debugName: 'price-drop-simulator',
  );
}

ListingHealthAnalysisResult _analyzeOnWorker({
  required DeadListingsInsight report,
  required List<MaterialEntity> sellerListings,
  required List<MaterialEntity> allMarketplaceListings,
  required String sellerId,
  required int staleDays,
  required Set<String> dismissedIds,
  required Map<String, double> localPriceOverrides,
  required DateTime now,
}) {
  final sw = Stopwatch()..start();
  final categoryMedians = _computeCategoryMedians(
    report: report,
    marketplaceListings: allMarketplaceListings,
  );

  final sellerAvailableById = <String, MaterialEntity>{
    for (final m in sellerListings)
      if (m.sellerId == sellerId && m.isAvailable) m.id: m,
  };

  final merged = <SellerListingHealthItem>[];
  var usedFallback = false;

  if (report.atRiskListings.isNotEmpty) {
    final seenIds = <String>{};
    for (final item in report.atRiskListings) {
      seenIds.add(item.id);
      final localEntity = sellerAvailableById[item.id];
      final effectivePrice = localPriceOverrides[item.id] ?? localEntity?.price ?? item.price;
      if ((effectivePrice - item.price).abs() > 0.009) {
        merged.add(
          _reEvaluateWithPrice(
            item: item,
            newPrice: effectivePrice,
            categoryMedian: item.categoryMedianPrice ?? categoryMedians[item.category],
            staleDays: staleDays,
          ),
        );
      } else {
        merged.add(item);
      }
    }
    // Include newly created or cached seller listings not yet reflected in BQ 10.
    for (final m in sellerAvailableById.values) {
      if (seenIds.contains(m.id)) continue;
      final evaluated = _evaluateMaterialLocally(
        material: m,
        overridePrice: localPriceOverrides[m.id],
        categoryMedian: categoryMedians[m.category.name],
        clusters: report.clusters,
        staleDays: staleDays,
        now: now,
      );
      if (evaluated.isDead || evaluated.riskScore >= 15) {
        merged.add(evaluated);
      }
    }
  } else {
    // Offline cold-start or empty analytics response: score cached marketplace items locally.
    usedFallback = sellerAvailableById.isNotEmpty;
    for (final m in sellerAvailableById.values) {
      merged.add(
        _evaluateMaterialLocally(
          material: m,
          overridePrice: localPriceOverrides[m.id],
          categoryMedian: categoryMedians[m.category.name],
          clusters: report.clusters,
          staleDays: staleDays,
          now: now,
        ),
      );
    }
  }

  merged.sort((a, b) {
    final deadCmp = (b.isDead ? 1 : 0).compareTo(a.isDead ? 1 : 0);
    if (deadCmp != 0) return deadCmp;
    final riskCmp = b.riskScore.compareTo(a.riskScore);
    if (riskCmp != 0) return riskCmp;
    final daysCmp = b.daysActive.compareTo(a.daysActive);
    if (daysCmp != 0) return daysCmp;
    return a.title.compareTo(b.title);
  });

  final active = <SellerListingHealthItem>[];
  final dismissed = <SellerListingHealthItem>[];
  for (final item in merged) {
    if (dismissedIds.contains(item.id)) {
      dismissed.add(item);
    } else {
      active.add(item);
    }
  }

  sw.stop();
  return ListingHealthAnalysisResult(
    activeAdvisories: List.unmodifiable(active),
    dismissedAdvisories: List.unmodifiable(dismissed),
    categoryMedians: Map.unmodifiable(categoryMedians),
    usedLocalFallback: usedFallback,
    elapsedMicroseconds: sw.elapsedMicroseconds,
  );
}

Map<String, double> _computeCategoryMedians({
  required DeadListingsInsight report,
  required List<MaterialEntity> marketplaceListings,
}) {
  final medians = <String, double>{};
  for (final item in [...report.deadListings, ...report.atRiskListings]) {
    if (item.categoryMedianPrice != null && item.categoryMedianPrice! > 0) {
      medians[item.category] = item.categoryMedianPrice!;
    }
  }
  final pricesByCat = <String, List<double>>{};
  for (final m in marketplaceListings) {
    if (m.price > 0) {
      pricesByCat.putIfAbsent(m.category.name, () => <double>[]).add(m.price);
    }
  }
  for (final entry in pricesByCat.entries) {
    if (!medians.containsKey(entry.key) && entry.value.isNotEmpty) {
      final sorted = List<double>.of(entry.value)..sort();
      final mid = sorted.length ~/ 2;
      medians[entry.key] = sorted.length.isOdd
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2.0;
    }
  }
  return medians;
}

SellerListingHealthItem _evaluateMaterialLocally({
  required MaterialEntity material,
  double? overridePrice,
  required double? categoryMedian,
  required List<DeadListingCluster> clusters,
  required int staleDays,
  required DateTime now,
}) {
  final effectivePrice = overridePrice ?? material.price;
  final daysActive = math.max(0.0, now.difference(material.createdAt.toUtc()).inHours / 24.0);
  final photos = material.imageUrls.length;
  final sellerRating = material.seller?.rating ?? 0.0;
  final ratio = (effectivePrice > 0 && categoryMedian != null && categoryMedian > 0)
      ? effectivePrice / categoryMedian
      : null;

  final scored = _scoreSignals(
    daysActive: daysActive,
    price: effectivePrice,
    categoryMedian: categoryMedian,
    priceRatio: ratio,
    photos: photos,
    contacts: 0,
    sellerRating: sellerRating,
    staleDays: staleDays,
  );

  String? matchedClusterLabel;
  String? matchedClusterId;
  if (scored.isDead && clusters.isNotEmpty) {
    final best = _nearestCluster(
      clusters: clusters,
      priceRatio: ratio ?? 1.0,
      photos: photos.toDouble(),
      sellerRating: sellerRating,
      daysActive: daysActive,
    );
    matchedClusterId = best?.clusterId;
    matchedClusterLabel = best?.label;
  }

  return SellerListingHealthItem(
    id: material.id,
    title: material.title,
    category: material.category.name,
    price: double.parse(effectivePrice.toStringAsFixed(2)),
    categoryMedianPrice: categoryMedian != null ? double.parse(categoryMedian.toStringAsFixed(2)) : null,
    priceRatio: ratio != null ? double.parse(ratio.toStringAsFixed(4)) : null,
    suggestedPrice: scored.suggestedPrice,
    recommendedDropPct: scored.recommendedDropPct,
    photos: photos,
    contacts: 0,
    sellerId: material.sellerId,
    sellerRating: sellerRating,
    daysActive: double.parse(daysActive.toStringAsFixed(2)),
    isDead: scored.isDead,
    clusterId: matchedClusterId,
    clusterLabel: matchedClusterLabel,
    riskScore: scored.riskScore,
    riskLevel: scored.riskLevel,
    reasons: scored.reasons,
    recommendation: scored.recommendation,
  );
}

SellerListingHealthItem _reEvaluateWithPrice({
  required SellerListingHealthItem item,
  required double newPrice,
  required double? categoryMedian,
  required int staleDays,
}) {
  final ratio = (newPrice > 0 && categoryMedian != null && categoryMedian > 0)
      ? newPrice / categoryMedian
      : null;
  final scored = _scoreSignals(
    daysActive: item.daysActive,
    price: newPrice,
    categoryMedian: categoryMedian,
    priceRatio: ratio,
    photos: item.photos,
    contacts: item.contacts,
    sellerRating: item.sellerRating,
    staleDays: staleDays,
  );
  return item.copyWith(
    price: double.parse(newPrice.toStringAsFixed(2)),
    categoryMedianPrice: categoryMedian,
    priceRatio: ratio != null ? double.parse(ratio.toStringAsFixed(4)) : null,
    suggestedPrice: scored.suggestedPrice,
    recommendedDropPct: scored.recommendedDropPct,
    isDead: scored.isDead,
    riskScore: scored.riskScore,
    riskLevel: scored.riskLevel,
    reasons: scored.reasons,
    recommendation: scored.recommendation,
  );
}

PriceDropSimulation _simulatePriceDropWorker({
  required SellerListingHealthItem item,
  required double newPrice,
  required int staleDays,
  double? baselineCategorySellDays,
}) {
  final clampedPrice = math.max(1.0, newPrice);
  final originalPrice = item.price > 0 ? item.price : clampedPrice;
  final dropPct = ((originalPrice - clampedPrice) / originalPrice * 100.0).clamp(-100.0, 99.0);
  final median = item.categoryMedianPrice;
  final projectedRatio = (median != null && median > 0) ? clampedPrice / median : null;

  final scored = _scoreSignals(
    daysActive: item.daysActive,
    price: clampedPrice,
    categoryMedian: median,
    priceRatio: projectedRatio,
    photos: item.photos,
    contacts: item.contacts,
    sellerRating: item.sellerRating,
    staleDays: staleDays,
  );

  // Additional liquidity benefit when lowering price >= 10% below previous ask.
  var adjustedRisk = scored.riskScore;
  if (dropPct >= 20) {
    adjustedRisk = math.max(0, adjustedRisk - 10);
  } else if (dropPct >= 10) {
    adjustedRisk = math.max(0, adjustedRisk - 5);
  }
  final level = _levelForRisk(isDead: item.isDead, riskScore: adjustedRisk);

  double? estimatedSellDays;
  final baseDays = baselineCategorySellDays ?? (staleDays * 0.65);
  if (baseDays > 0) {
    final ratioFactor = projectedRatio ?? (1.0 - (dropPct / 100.0).clamp(-0.5, 0.5));
    estimatedSellDays = double.parse((baseDays * math.max(0.45, math.min(2.0, ratioFactor))).toStringAsFixed(1));
  }

  final reduction = math.max(0, item.riskScore - adjustedRisk);
  final String summary;
  if (dropPct <= 0) {
    summary = 'Current price leaves stale risk at ${item.riskScore}/100.';
  } else if (projectedRatio != null && projectedRatio <= 1.05) {
    summary = 'Competitive with category median (-$reduction risk pts).';
  } else if (reduction > 0) {
    summary = 'Cuts stale risk by $reduction pts (to $adjustedRisk/100).';
  } else {
    summary = 'Lower price improves visibility; adding photos cuts risk further.';
  }

  return PriceDropSimulation(
    listingId: item.id,
    originalPrice: originalPrice,
    newPrice: double.parse(clampedPrice.toStringAsFixed(2)),
    dropPercent: double.parse(dropPct.toStringAsFixed(1)),
    currentRiskScore: item.riskScore,
    projectedRiskScore: adjustedRisk,
    projectedRiskLevel: level,
    projectedPriceRatio: projectedRatio != null ? double.parse(projectedRatio.toStringAsFixed(4)) : null,
    estimatedSellDays: estimatedSellDays,
    summaryText: summary,
  );
}

class _ScoreBreakdown {
  final int riskScore;
  final String riskLevel;
  final bool isDead;
  final List<String> reasons;
  final double? suggestedPrice;
  final double recommendedDropPct;
  final String recommendation;

  const _ScoreBreakdown({
    required this.riskScore,
    required this.riskLevel,
    required this.isDead,
    required this.reasons,
    required this.suggestedPrice,
    required this.recommendedDropPct,
    required this.recommendation,
  });
}

_ScoreBreakdown _scoreSignals({
  required double daysActive,
  required double price,
  required double? categoryMedian,
  required double? priceRatio,
  required int photos,
  required int contacts,
  required double sellerRating,
  required int staleDays,
}) {
  final isDead = daysActive >= staleDays;
  final reasons = <String>[];
  var score = 0.0;

  score += math.min(40.0, (daysActive / math.max(1, staleDays)) * 20.0);
  if (isDead) {
    reasons.add('Unsold for ${daysActive.toStringAsFixed(1)} days (threshold ${staleDays}d)');
  } else if (daysActive >= math.max(1.0, staleDays * 0.5)) {
    reasons.add('Active for ${daysActive.toStringAsFixed(1)} days with no sale yet');
  }

  if (priceRatio != null && priceRatio > 1.15) {
    final overPct = ((priceRatio - 1.0) * 100).round();
    score += priceRatio >= 1.40 ? 30.0 : 18.0;
    reasons.add('Priced $overPct% above category median');
  }

  if (photos == 0) {
    score += 20.0;
    reasons.add('No photos uploaded');
  } else if (photos == 1) {
    score += 10.0;
    reasons.add('Only 1 photo (3+ photos attract more buyers)');
  }

  if (sellerRating <= 0) {
    score += 5.0;
    reasons.add('New or unrated seller profile');
  } else if (sellerRating < 3.5) {
    score += 12.0;
    reasons.add('Low seller rating (${sellerRating.toStringAsFixed(1)}/5)');
  }

  if (contacts == 0 && daysActive >= 3.0) {
    score += 10.0;
    reasons.add('No buyer messages yet');
  }

  final riskScore = math.min(100, score.round());
  final riskLevel = _levelForRisk(isDead: isDead, riskScore: riskScore);

  double? suggestedPrice;
  var recommendedDropPct = 0.0;
  if (price > 0) {
    if (categoryMedian != null && categoryMedian > 0 && priceRatio != null && priceRatio > 1.15) {
      final target = categoryMedian * (isDead && contacts == 0 ? 0.95 : 1.0);
      suggestedPrice = _roundSuggestedPrice(target, price);
    } else if (isDead) {
      suggestedPrice = _roundSuggestedPrice(price * 0.85, price);
    }
  }
  if (suggestedPrice != null && price > 0) {
    recommendedDropPct = double.parse(((price - suggestedPrice) / price * 100.0).toStringAsFixed(1));
  }

  final actions = <String>[];
  if (suggestedPrice != null) {
    actions.add('Drop price by ~${recommendedDropPct.round()}% (to ${suggestedPrice.toStringAsFixed(0)})');
  }
  if (photos < 2) {
    actions.add('add 2-3 clear photos');
  }
  if (contacts == 0 && actions.isEmpty) {
    actions.add('refresh title & course code');
  }
  final recommendation = actions.isEmpty
      ? 'Healthy pace - monitor inquiries.'
      : '${actions.join('; ')}.';

  return _ScoreBreakdown(
    riskScore: riskScore,
    riskLevel: riskLevel,
    isDead: isDead,
    reasons: List.unmodifiable(reasons),
    suggestedPrice: suggestedPrice,
    recommendedDropPct: recommendedDropPct,
    recommendation: recommendation.length > 1
        ? '${recommendation[0].toUpperCase()}${recommendation.substring(1)}'
        : recommendation,
  );
}

String _levelForRisk({required bool isDead, required int riskScore}) {
  if (isDead || riskScore >= 60) return 'high';
  if (riskScore >= 35) return 'medium';
  if (riskScore >= 15) return 'watch';
  return 'low';
}

double? _roundSuggestedPrice(double target, double currentPrice) {
  if (currentPrice <= 0 || target <= 0) return null;
  var rounded = currentPrice >= 1000
      ? (target / 100.0).round() * 100.0
      : double.parse(target.toStringAsFixed(2));
  final ceiling = currentPrice < 1000
      ? double.parse((currentPrice * 0.95).toStringAsFixed(2))
      : (currentPrice.floor() - 100).toDouble();
  rounded = math.min(rounded, ceiling);
  if (rounded <= 0 || rounded >= currentPrice) {
    return currentPrice > 1 ? double.parse(math.max(1.0, currentPrice * 0.85).toStringAsFixed(2)) : null;
  }
  return double.parse(rounded.toStringAsFixed(2));
}

DeadListingCluster? _nearestCluster({
  required List<DeadListingCluster> clusters,
  required double priceRatio,
  required double photos,
  required double sellerRating,
  required double daysActive,
}) {
  DeadListingCluster? best;
  var bestDist = double.infinity;
  for (final c in clusters) {
    final d = math.pow((priceRatio - c.avgPriceRatio) * 2.0, 2) +
        math.pow((photos - c.avgPhotos), 2) +
        math.pow((sellerRating - c.avgSellerRating), 2) +
        math.pow((daysActive - c.avgDaysActive) / 14.0, 2);
    if (d < bestDist) {
      bestDist = d.toDouble();
      best = c;
    }
  }
  return best;
}
