import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/course_demand_model.dart';
import '../../entities/course_demand.dart';
import '../course_demand_repository.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// Network falling back to the copy in `cached_responses`. The figures are the same for every
/// account, so one copy is saved for all ('global'), like the other analytics cards.
class CourseDemandRepositoryImpl implements CourseDemandRepository {
  static const String cacheOwner = 'global';
  static const String cacheKey = 'course_demand_bq19';

  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  CourseDemandRepositoryImpl({required this.remote, this.cache});

  @override
  Future<({CourseDemandReport report, DateTime? savedAt})> getCourseDemand() {
    final cache = this.cache;
    if (cache == null) {
      return guardRequest(
        () async => (report: courseDemandFromJson(await remote.getCourseDemandJson()), savedAt: null),
      );
    }
    return guardRequest(() async {
      final result = await cache.networkFirst(
        ownerId: cacheOwner,
        key: cacheKey,
        fetch: remote.getCourseDemandJson,
        parse: courseDemandFromJson,
      );
      return (report: result.data, savedAt: result.savedAt);
    });
  }
}
