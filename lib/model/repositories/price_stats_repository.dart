import '../entities/price_stats.dart';

abstract class PriceStatsRepository {
  /// Price statistics of completed sales. [category] and [condition] are the enum names
  /// (e.g. `BOOKS`, `GOOD`). Throws when the analytics service cannot be reached.
  Future<PriceStats> getPriceStats({required String category, required String condition});
}
