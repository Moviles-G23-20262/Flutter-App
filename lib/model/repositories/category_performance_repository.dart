import '../entities/cached_list.dart';
import '../entities/category_performance.dart';

abstract class CategoryPerformanceRepository {
  /// BQ6: listings and completed exchanges per category. Offline (or with a 5xx), the copy saved
  /// at the last successful load, with its `savedAt`. Throws `DataException`
  /// (`NoConnectionException` when offline with nothing saved).
  Future<CachedList<CategoryPerformance>> getCategoryPerformance();
}
