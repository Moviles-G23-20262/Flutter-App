import '../entities/time_to_sell.dart';

class TimeToSellModel extends TimeToSellInsight {
  const TimeToSellModel({
    required super.soldListings,
    super.skipped,
    required super.meanDays,
    required super.medianDays,
    super.p75Days,
    super.minDays,
    super.maxDays,
    super.categoryMeans,
    super.categoryMedians,
  });

  /// Parses GET /analytics/time-to-sell/
  factory TimeToSellModel.fromJson(Map<String, dynamic> json) {
    final days = (json['days_to_sell'] as Map<String, dynamic>?) ?? {};
    final byCat = (json['by_category'] as List<dynamic>?) ?? [];

    final means = <String, double>{};
    final medians = <String, double>{};
    for (final item in byCat) {
      if (item is Map<String, dynamic>) {
        final cat = item['category']?.toString().toUpperCase();
        if (cat != null) {
          final mean = (item['mean_days'] as num?)?.toDouble() ??
              (item['mean'] as num?)?.toDouble() ??
              0.0;
          final median = (item['median_days'] as num?)?.toDouble() ??
              (item['median'] as num?)?.toDouble() ??
              0.0;
          means[cat] = mean;
          medians[cat] = median;
        }
      }
    }

    return TimeToSellModel(
      soldListings: (json['sold_listings'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      meanDays: (days['mean'] as num?)?.toDouble() ?? 0.0,
      medianDays: (days['median'] as num?)?.toDouble() ?? 0.0,
      p75Days: (days['p75'] as num?)?.toDouble() ?? 0.0,
      minDays: (days['min'] as num?)?.toDouble() ?? 0.0,
      maxDays: (days['max'] as num?)?.toDouble() ?? 0.0,
      categoryMeans: means,
      categoryMedians: medians,
    );
  }

  Map<String, dynamic> toJson() => {
    'sold_listings': soldListings,
    'skipped': skipped,
    'days_to_sell': {
      'mean': meanDays,
      'median': medianDays,
      'p75': p75Days,
      'min': minDays,
      'max': maxDays,
    },
    'by_category': categoryMeans.keys.map((cat) => {
      'category': cat,
      'mean_days': categoryMeans[cat] ?? 0.0,
      'median_days': categoryMedians[cat] ?? 0.0,
    }).toList(),
  };
}
