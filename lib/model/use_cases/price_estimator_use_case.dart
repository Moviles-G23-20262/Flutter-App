import '../entities/material_entity.dart';
import '../entities/price_stats.dart';
import '../repositories/price_stats_repository.dart';

/// Where an estimate comes from, so the UI can be honest about how reliable it is.
enum PriceEstimateSource {
  /// Percentiles of real completed sales from the analytics service.
  realSales,

  /// Local formula because the analytics service could not be reached.
  offlineHeuristic,

  /// Local formula because there are too few completed sales to trust.
  lowSampleHeuristic,
}

/// Estimated price band for a listing.
class PriceEstimate {
  /// 25th percentile of prices.
  final double p25;

  /// 75th percentile of prices.
  final double p75;

  /// Recommended asking price (the median of comparable sales).
  final double suggestedPrice;

  /// Completed sales the estimate is based on; 0 for a heuristic estimate.
  final int sampleSize;

  final PriceEstimateSource source;

  const PriceEstimate({
    required this.p25,
    required this.p75,
    required this.suggestedPrice,
    this.sampleSize = 0,
    this.source = PriceEstimateSource.offlineHeuristic,
  });

  bool get isHeuristic => source != PriceEstimateSource.realSales;
}

/// Smart price estimator: asks the analytics service for the p25 / median / p75 of real
/// completed sales and falls back to an in-memory heuristic when there is no connection,
/// the server fails, or fewer than [minSamples] sales back the figures. It never throws.
class PriceEstimatorUseCase {
  /// Fewer sales than this and the statistics are not trusted.
  static const int minSamples = 5;
  static const Duration timeout = Duration(seconds: 8);

  /// Null means "heuristic only" (no analytics service configured).
  final PriceStatsRepository? repository;

  const PriceEstimatorUseCase({this.repository});

  /// Base price in COP of a new item of each category.
  static const Map<MaterialCategoryEnum, double> _basePrice = {
    MaterialCategoryEnum.BOOKS: 45000,
    MaterialCategoryEnum.CALCULATORS: 120000,
    MaterialCategoryEnum.LAB_EQUIPMENT: 70000,
    MaterialCategoryEnum.FURNITURE: 150000,
    MaterialCategoryEnum.OTHER: 30000,
  };

  /// Share of the new price that an item keeps in each condition.
  static const Map<MaterialConditionEnum, double> _conditionFactor = {
    MaterialConditionEnum.NEW: 1.0,
    MaterialConditionEnum.LIKE_NEW: 0.85,
    MaterialConditionEnum.GOOD: 0.65,
    MaterialConditionEnum.FAIR: 0.45,
  };

  /// Half-width of the fair range as a share of the price: the worse the condition,
  /// the more sellers disagree on its worth.
  static const Map<MaterialConditionEnum, double> _spread = {
    MaterialConditionEnum.NEW: 0.10,
    MaterialConditionEnum.LIKE_NEW: 0.12,
    MaterialConditionEnum.GOOD: 0.18,
    MaterialConditionEnum.FAIR: 0.25,
  };

  static const double _roundTo = 1000;

  Future<PriceEstimate> execute({
    required MaterialCategoryEnum category,
    required MaterialConditionEnum condition,
  }) async {
    final repo = repository;
    if (repo == null) return heuristic(category: category, condition: condition);

    final PriceStats stats;
    try {
      stats = await repo
          .getPriceStats(category: category.name, condition: condition.name)
          .timeout(timeout);
    } catch (_) {
      return heuristic(category: category, condition: condition);
    }

    if (!_isUsable(stats)) return heuristic(category: category, condition: condition);
    if (stats.sampleSize < minSamples) {
      return heuristic(
        category: category,
        condition: condition,
        source: PriceEstimateSource.lowSampleHeuristic,
      );
    }
    return PriceEstimate(
      p25: stats.p25,
      p75: stats.p75,
      suggestedPrice: stats.median,
      sampleSize: stats.sampleSize,
      source: PriceEstimateSource.realSales,
    );
  }

  /// Local estimate from category and condition: base price x condition factor, with a
  /// symmetric band around it. Instant, works offline and never fails.
  PriceEstimate heuristic({
    required MaterialCategoryEnum category,
    required MaterialConditionEnum condition,
    PriceEstimateSource source = PriceEstimateSource.offlineHeuristic,
  }) {
    final price = (_basePrice[category] ?? 30000) * (_conditionFactor[condition] ?? 0.65);
    final spread = _spread[condition] ?? 0.18;
    double round(double v) => (v / _roundTo).round() * _roundTo;
    return PriceEstimate(
      p25: round(price * (1 - spread)),
      p75: round(price * (1 + spread)),
      suggestedPrice: round(price),
      source: source,
    );
  }

  static bool _isUsable(PriceStats s) =>
      s.median > 0 && s.p25 > 0 && s.p25 <= s.median && s.median <= s.p75;
}
