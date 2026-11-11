import '../entities/dead_listings_insight.dart';

class DeadListingsModel extends DeadListingsInsight {
  const DeadListingsModel({
    required super.summary,
    super.survivalCurve,
    super.clusters,
    super.deadListings,
    super.atRiskListings,
    super.sellerSummary,
  });

  /// Parses GET /analytics/dead-listings/
  factory DeadListingsModel.fromJson(Map<String, dynamic> json) {
    final s = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final summary = DeadListingSummary(
      totalListings: (s['total_listings'] as num?)?.toInt() ?? 0,
      soldListings: (s['sold_listings'] as num?)?.toInt() ?? 0,
      reservedListings: (s['reserved_listings'] as num?)?.toInt() ?? 0,
      activeFreshListings: (s['active_fresh_listings'] as num?)?.toInt() ?? 0,
      deadListings: (s['dead_listings'] as num?)?.toInt() ?? 0,
      skipped: (s['skipped'] as num?)?.toInt() ?? 0,
      staleDays: (s['stale_days'] as num?)?.toInt() ?? 14,
      deadShare: (s['dead_share'] as num?)?.toDouble() ?? 0.0,
      neverSoldShare: (s['never_sold_share'] as num?)?.toDouble() ?? 0.0,
      medianDaysActiveDead: (s['median_days_active_dead'] as num?)?.toDouble() ?? 0.0,
      meanDaysActiveDead: (s['mean_days_active_dead'] as num?)?.toDouble() ?? 0.0,
      medianDaysToSell: (s['median_days_to_sell'] as num?)?.toDouble() ?? 0.0,
    );

    final curveRaw = (json['survival_curve'] as List<dynamic>?) ?? const [];
    final survivalCurve = curveRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (p) => DeadSurvivalPoint(
            day: (p['day'] as num?)?.toInt() ?? 0,
            survivalRate: (p['survival_rate'] as num?)?.toDouble() ?? 0.0,
            atRisk: (p['at_risk'] as num?)?.toInt() ?? 0,
            soldCumulative: (p['sold_cumulative'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);

    final clustersRaw = (json['clusters'] as List<dynamic>?) ?? const [];
    final clusters = clustersRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (c) => DeadListingCluster(
            clusterId: c['cluster_id']?.toString() ?? '',
            label: c['label']?.toString() ?? 'Pattern cluster',
            recommendedAction: c['recommended_action']?.toString() ?? '',
            count: (c['count'] as num?)?.toInt() ?? 0,
            share: (c['share'] as num?)?.toDouble() ?? 0.0,
            avgPriceRatio: (c['avg_price_ratio'] as num?)?.toDouble() ?? 1.0,
            medianPriceRatio: (c['median_price_ratio'] as num?)?.toDouble() ?? 1.0,
            avgPhotos: (c['avg_photos'] as num?)?.toDouble() ?? 0.0,
            avgSellerRating: (c['avg_seller_rating'] as num?)?.toDouble() ?? 0.0,
            avgDaysActive: (c['avg_days_active'] as num?)?.toDouble() ?? 0.0,
            medianDaysActive: (c['median_days_active'] as num?)?.toDouble() ?? 0.0,
            zeroContactShare: (c['zero_contact_share'] as num?)?.toDouble() ?? 0.0,
            topCategory: c['top_category']?.toString() ?? 'OTHER',
          ),
        )
        .toList(growable: false);

    final deadListings = ((json['dead_listings'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_healthItemFromJson)
        .toList(growable: false);

    final atRiskListings = ((json['at_risk_listings'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_healthItemFromJson)
        .toList(growable: false);

    final ss = json['seller_summary'] as Map<String, dynamic>?;
    final sellerSummary = ss == null
        ? null
        : SellerHealthOverview(
            sellerId: ss['seller_id']?.toString() ?? '',
            totalListings: (ss['total_listings'] as num?)?.toInt() ?? 0,
            soldListings: (ss['sold_listings'] as num?)?.toInt() ?? 0,
            reservedListings: (ss['reserved_listings'] as num?)?.toInt() ?? 0,
            activeFreshListings: (ss['active_fresh_listings'] as num?)?.toInt() ?? 0,
            deadListings: (ss['dead_listings'] as num?)?.toInt() ?? 0,
            atRiskCount: (ss['at_risk_count'] as num?)?.toInt() ?? 0,
            healthyListings: (ss['healthy_listings'] as num?)?.toInt() ?? 0,
          );

    return DeadListingsModel(
      summary: summary,
      survivalCurve: survivalCurve,
      clusters: clusters,
      deadListings: deadListings,
      atRiskListings: atRiskListings,
      sellerSummary: sellerSummary,
    );
  }

  static SellerListingHealthItem _healthItemFromJson(Map<String, dynamic> item) {
    final rawReasons = (item['reasons'] as List<dynamic>?) ?? const [];
    return SellerListingHealthItem(
      id: item['id']?.toString() ?? '',
      title: item['title']?.toString() ?? 'Untitled',
      category: item['category']?.toString() ?? 'OTHER',
      price: (item['price'] as num?)?.toDouble() ?? 0.0,
      categoryMedianPrice: (item['category_median_price'] as num?)?.toDouble(),
      priceRatio: (item['price_ratio'] as num?)?.toDouble(),
      suggestedPrice: (item['suggested_price'] as num?)?.toDouble(),
      recommendedDropPct: (item['recommended_drop_pct'] as num?)?.toDouble() ?? 0.0,
      photos: (item['photos'] as num?)?.toInt() ?? 0,
      contacts: (item['contacts'] as num?)?.toInt() ?? 0,
      sellerId: item['seller_id']?.toString() ?? '',
      sellerRating: (item['seller_rating'] as num?)?.toDouble() ?? 0.0,
      daysActive: (item['days_active'] as num?)?.toDouble() ?? 0.0,
      isDead: item['is_dead'] == true,
      clusterId: item['cluster_id']?.toString(),
      clusterLabel: item['cluster_label']?.toString(),
      riskScore: (item['risk_score'] as num?)?.toInt() ?? 0,
      riskLevel: item['risk_level']?.toString() ?? 'low',
      reasons: rawReasons.map((r) => r.toString()).toList(growable: false),
      recommendation: item['recommendation']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> toJson(DeadListingsInsight insight) => {
        'summary': {
          'total_listings': insight.summary.totalListings,
          'sold_listings': insight.summary.soldListings,
          'reserved_listings': insight.summary.reservedListings,
          'active_fresh_listings': insight.summary.activeFreshListings,
          'dead_listings': insight.summary.deadListings,
          'skipped': insight.summary.skipped,
          'stale_days': insight.summary.staleDays,
          'dead_share': insight.summary.deadShare,
          'never_sold_share': insight.summary.neverSoldShare,
          'median_days_active_dead': insight.summary.medianDaysActiveDead,
          'mean_days_active_dead': insight.summary.meanDaysActiveDead,
          'median_days_to_sell': insight.summary.medianDaysToSell,
        },
        'survival_curve': insight.survivalCurve
            .map((p) => {
                  'day': p.day,
                  'survival_rate': p.survivalRate,
                  'at_risk': p.atRisk,
                  'sold_cumulative': p.soldCumulative,
                })
            .toList(growable: false),
        'clusters': insight.clusters
            .map((c) => {
                  'cluster_id': c.clusterId,
                  'label': c.label,
                  'recommended_action': c.recommendedAction,
                  'count': c.count,
                  'share': c.share,
                  'avg_price_ratio': c.avgPriceRatio,
                  'median_price_ratio': c.medianPriceRatio,
                  'avg_photos': c.avgPhotos,
                  'avg_seller_rating': c.avgSellerRating,
                  'avg_days_active': c.avgDaysActive,
                  'median_days_active': c.medianDaysActive,
                  'zero_contact_share': c.zeroContactShare,
                  'top_category': c.topCategory,
                })
            .toList(growable: false),
        'dead_listings': insight.deadListings.map(_healthItemToJson).toList(growable: false),
        'at_risk_listings': insight.atRiskListings.map(_healthItemToJson).toList(growable: false),
        if (insight.sellerSummary != null)
          'seller_summary': {
            'seller_id': insight.sellerSummary!.sellerId,
            'total_listings': insight.sellerSummary!.totalListings,
            'sold_listings': insight.sellerSummary!.soldListings,
            'reserved_listings': insight.sellerSummary!.reservedListings,
            'active_fresh_listings': insight.sellerSummary!.activeFreshListings,
            'dead_listings': insight.sellerSummary!.deadListings,
            'at_risk_count': insight.sellerSummary!.atRiskCount,
            'healthy_listings': insight.sellerSummary!.healthyListings,
          },
      };

  static Map<String, dynamic> _healthItemToJson(SellerListingHealthItem item) => {
        'id': item.id,
        'title': item.title,
        'category': item.category,
        'price': item.price,
        'category_median_price': item.categoryMedianPrice,
        'price_ratio': item.priceRatio,
        'suggested_price': item.suggestedPrice,
        'recommended_drop_pct': item.recommendedDropPct,
        'photos': item.photos,
        'contacts': item.contacts,
        'seller_id': item.sellerId,
        'seller_rating': item.sellerRating,
        'days_active': item.daysActive,
        'is_dead': item.isDead,
        'cluster_id': item.clusterId,
        'cluster_label': item.clusterLabel,
        'risk_score': item.riskScore,
        'risk_level': item.riskLevel,
        'reasons': item.reasons,
        'recommendation': item.recommendation,
      };
}
