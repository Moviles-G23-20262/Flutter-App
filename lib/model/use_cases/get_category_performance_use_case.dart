import '../entities/cached_list.dart';
import '../entities/category_performance.dart';
import '../repositories/category_performance_repository.dart';

/// BQ6: which item categories get the most listings and the most completed exchanges.
class GetCategoryPerformanceUseCase {
  final CategoryPerformanceRepository repository;

  GetCategoryPerformanceUseCase(this.repository);

  Future<CachedList<CategoryPerformance>> execute() => repository.getCategoryPerformance();
}
