import 'package:flutter/foundation.dart';

/// Top-level marketplace summary from BQ 10 (`/analytics/dead-listings/`).
@immutable
class DeadListingSummary {
  final int totalListings;
  final int soldListings;
  final int reservedListings;
  final int activeFreshListings;
  final int deadListings;
  final int skipped;
  final int staleDays;
  final double deadShare;
  final double neverSoldShare;
  final double medianDaysActiveDead;
  final double meanDaysActiveDead;
  final double medianDaysToSell;

  const DeadListingSummary({
    required this.totalListings,
    required this.soldListings,
    required this.reservedListings,
    required this.activeFreshListings,
    required this.deadListings,
    this.skipped = 0,
    required this.staleDays,
    required this.deadShare,
    required this.neverSoldShare,
    required this.medianDaysActiveDead,
    this.meanDaysActiveDead = 0.0,
    required this.medianDaysToSell,
  });

  static const empty = DeadListingSummary(
    totalListings: 0,
    soldListings: 0,
    reservedListings: 0,
    activeFreshListings: 0,
    deadListings: 0,
    skipped: 0,
    staleDays: 14,
    deadShare: 0.0,
    neverSoldShare: 0.0,
    medianDaysActiveDead: 0.0,
    meanDaysActiveDead: 0.0,
    medianDaysToSell: 0.0,
  );
}

/// One checkpoint on the Kaplan-Meier unsold survival curve.
@immutable
class DeadSurvivalPoint {
  final int day;
  final double survivalRate;
  final int atRisk;
  final int soldCumulative;

  const DeadSurvivalPoint({
    required this.day,
    required this.survivalRate,
    required this.atRisk,
    required this.soldCumulative,
  });
}

/// One hidden pattern cluster discovered across dead/unsold listings by K-Means.
@immutable
class DeadListingCluster {
  final String clusterId;
  final String label;
  final String recommendedAction;
  final int count;
  final double share;
  final double avgPriceRatio;
  final double medianPriceRatio;
  final double avgPhotos;
  final double avgSellerRating;
  final double avgDaysActive;
  final double medianDaysActive;
  final double zeroContactShare;
  final String topCategory;

  const DeadListingCluster({
    required this.clusterId,
    required this.label,
    required this.recommendedAction,
    required this.count,
    required this.share,
    required this.avgPriceRatio,
    this.medianPriceRatio = 1.0,
    required this.avgPhotos,
    required this.avgSellerRating,
    required this.avgDaysActive,
    required this.medianDaysActive,
    required this.zeroContactShare,
    required this.topCategory,
  });
}

/// Risk evaluation & price-drop recommendation for a single seller listing.
@immutable
class SellerListingHealthItem {
  final String id;
  final String title;
  final String category;
  final double price;
  final double? categoryMedianPrice;
  final double? priceRatio;
  final double? suggestedPrice;
  final double recommendedDropPct;
  final int photos;
  final int contacts;
  final String sellerId;
  final double sellerRating;
  final double daysActive;
  final bool isDead;
  final String? clusterId;
  final String? clusterLabel;
  final int riskScore;
  final String riskLevel;
  final List<String> reasons;
  final String recommendation;

  const SellerListingHealthItem({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    this.categoryMedianPrice,
    this.priceRatio,
    this.suggestedPrice,
    required this.recommendedDropPct,
    required this.photos,
    required this.contacts,
    required this.sellerId,
    required this.sellerRating,
    required this.daysActive,
    required this.isDead,
    this.clusterId,
    this.clusterLabel,
    required this.riskScore,
    required this.riskLevel,
    required this.reasons,
    required this.recommendation,
  });

  SellerListingHealthItem copyWith({
    double? price,
    double? categoryMedianPrice,
    double? priceRatio,
    double? suggestedPrice,
    double? recommendedDropPct,
    int? photos,
    int? contacts,
    double? daysActive,
    bool? isDead,
    String? clusterId,
    String? clusterLabel,
    int? riskScore,
    String? riskLevel,
    List<String>? reasons,
    String? recommendation,
  }) {
    return SellerListingHealthItem(
      id: id,
      title: title,
      category: category,
      price: price ?? this.price,
      categoryMedianPrice: categoryMedianPrice ?? this.categoryMedianPrice,
      priceRatio: priceRatio ?? this.priceRatio,
      suggestedPrice: suggestedPrice ?? this.suggestedPrice,
      recommendedDropPct: recommendedDropPct ?? this.recommendedDropPct,
      photos: photos ?? this.photos,
      contacts: contacts ?? this.contacts,
      sellerId: sellerId,
      sellerRating: sellerRating,
      daysActive: daysActive ?? this.daysActive,
      isDead: isDead ?? this.isDead,
      clusterId: clusterId ?? this.clusterId,
      clusterLabel: clusterLabel ?? this.clusterLabel,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      reasons: reasons ?? this.reasons,
      recommendation: recommendation ?? this.recommendation,
    );
  }
}

/// Seller-scoped overview from BQ 10 when `?sellerId=<UUID>` is supplied.
@immutable
class SellerHealthOverview {
  final String sellerId;
  final int totalListings;
  final int soldListings;
  final int reservedListings;
  final int activeFreshListings;
  final int deadListings;
  final int atRiskCount;
  final int healthyListings;

  const SellerHealthOverview({
    required this.sellerId,
    required this.totalListings,
    required this.soldListings,
    required this.reservedListings,
    required this.activeFreshListings,
    required this.deadListings,
    required this.atRiskCount,
    required this.healthyListings,
  });
}

/// Full BQ 10 payload returned from the Django analytics backend (or SQLite cache).
@immutable
class DeadListingsInsight {
  final DeadListingSummary summary;
  final List<DeadSurvivalPoint> survivalCurve;
  final List<DeadListingCluster> clusters;
  final List<SellerListingHealthItem> deadListings;
  final List<SellerListingHealthItem> atRiskListings;
  final SellerHealthOverview? sellerSummary;

  const DeadListingsInsight({
    required this.summary,
    this.survivalCurve = const [],
    this.clusters = const [],
    this.deadListings = const [],
    this.atRiskListings = const [],
    this.sellerSummary,
  });

  static const empty = DeadListingsInsight(summary: DeadListingSummary.empty);

  bool get hasData =>
      summary.totalListings > 0 ||
      clusters.isNotEmpty ||
      atRiskListings.isNotEmpty ||
      deadListings.isNotEmpty;
}

/// Result of simulating a price cut for a specific listing in a background isolate.
@immutable
class PriceDropSimulation {
  final String listingId;
  final double originalPrice;
  final double newPrice;
  final double dropPercent;
  final int currentRiskScore;
  final int projectedRiskScore;
  final String projectedRiskLevel;
  final double? projectedPriceRatio;
  final double? estimatedSellDays;
  final String summaryText;

  const PriceDropSimulation({
    required this.listingId,
    required this.originalPrice,
    required this.newPrice,
    required this.dropPercent,
    required this.currentRiskScore,
    required this.projectedRiskScore,
    required this.projectedRiskLevel,
    this.projectedPriceRatio,
    this.estimatedSellDays,
    required this.summaryText,
  });

  int get riskReduction => (currentRiskScore - projectedRiskScore).clamp(0, 100);
}

/// Output of background isolate ranking and local overlay analysis.
@immutable
class ListingHealthAnalysisResult {
  final List<SellerListingHealthItem> activeAdvisories;
  final List<SellerListingHealthItem> dismissedAdvisories;
  final Map<String, double> categoryMedians;
  final bool usedLocalFallback;
  final int elapsedMicroseconds;

  const ListingHealthAnalysisResult({
    required this.activeAdvisories,
    required this.dismissedAdvisories,
    required this.categoryMedians,
    this.usedLocalFallback = false,
    this.elapsedMicroseconds = 0,
  });

  static const empty = ListingHealthAnalysisResult(
    activeAdvisories: [],
    dismissedAdvisories: [],
    categoryMedians: {},
  );
}
