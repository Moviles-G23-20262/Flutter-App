import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/category_performance_model.dart';
import '../../entities/cached_list.dart';
import '../../entities/category_performance.dart';
import '../category_performance_repository.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// Network falling back to the copy in `cached_responses` (only successful answers are saved).
/// The figures are the same for every account, so they are saved once ('global'), like the other
/// analytics insights.
class CategoryPerformanceRepositoryImpl implements CategoryPerformanceRepository {
  static const String cacheOwner = 'global';
  static const String cacheKey = 'category_performance';

  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  CategoryPerformanceRepositoryImpl({required this.remote, this.cache});

  @override
  Future<CachedList<CategoryPerformance>> getCategoryPerformance() {
    final cache = this.cache;
    if (cache == null) {
      return guardRequest(() async => CachedList(await remote.getCategoryPerformance()));
    }
    return guardRequest(() async {
      final result = await cache.networkFirst(
        ownerId: cacheOwner,
        key: cacheKey,
        fetch: () async => CategoryPerformanceModel.toJson(await remote.getCategoryPerformance()),
        parse: CategoryPerformanceModel.listFromJson,
      );
      return CachedList(result.data, savedAt: result.savedAt);
    });
  }
}
