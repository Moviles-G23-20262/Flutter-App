import '../../Domain/Entities/price_stats.dart';

class PriceStatsModel {
  /// Parses GET /analytics/price-stats/ (`sample_size`, `p25`, `median`, `p75`).
  static PriceStats fromJson(Map<String, dynamic> json) => PriceStats(
        sampleSize: (json['sample_size'] as num).toInt(),
        p25: (json['p25'] as num).toDouble(),
        median: (json['median'] as num).toDouble(),
        p75: (json['p75'] as num).toDouble(),
      );
}
