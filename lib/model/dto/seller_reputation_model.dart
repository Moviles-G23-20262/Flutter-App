import '../entities/seller_reputation.dart';

/// Parses and serializes `GET /analytics/seller-reputation/` (BQ 17).
abstract final class SellerReputationModel {
  static SellerReputationInsight fromJson(Object? json) {
    if (json is! Map) {
      return const SellerReputationInsight(
        listingsTotal: 0,
        sellersWithReviews: 0,
        byStars: [],
        byReviewCount: [],
      );
    }
    return SellerReputationInsight(
      listingsTotal: (json['listings_total'] as num?)?.toInt() ?? 0,
      sellersWithReviews: (json['sellers_with_reviews'] as num?)?.toInt() ?? 0,
      byStars: _parseTiers(json['by_stars']),
      byReviewCount: _parseTiers(json['by_review_count']),
    );
  }

  static List<ReputationTierStats> _parseTiers(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map && row['group'] is String)
          ReputationTierStats(
            group: row['group'] as String,
            label: (row['label'] as String?) ?? (row['group'] as String),
            sellers: (row['sellers'] as num?)?.toInt() ?? 0,
            listings: (row['listings'] as num?)?.toInt() ?? 0,
            contacted: (row['contacted'] as num?)?.toInt() ?? 0,
            contactRate: (row['contact_rate'] as num?)?.toDouble() ?? 0.0,
            buyersPerListing: (row['buyers_per_listing'] as num?)?.toDouble() ?? 0.0,
            sold: (row['sold'] as num?)?.toInt() ?? 0,
            saleRate: (row['sale_rate'] as num?)?.toDouble() ?? 0.0,
            medianDaysToSell: (row['median_days_to_sell'] as num?)?.toDouble(),
          ),
    ];
  }

  static Map<String, dynamic> toJson(SellerReputationInsight insight) => {
        'listings_total': insight.listingsTotal,
        'sellers_with_reviews': insight.sellersWithReviews,
        'by_stars': [for (final t in insight.byStars) _tierToJson(t)],
        'by_review_count': [for (final t in insight.byReviewCount) _tierToJson(t)],
      };

  static Map<String, dynamic> _tierToJson(ReputationTierStats t) => {
        'group': t.group,
        'label': t.label,
        'sellers': t.sellers,
        'listings': t.listings,
        'contacted': t.contacted,
        'contact_rate': t.contactRate,
        'buyers_per_listing': t.buyersPerListing,
        'sold': t.sold,
        'sale_rate': t.saleRate,
        'median_days_to_sell': t.medianDaysToSell,
      };
}
