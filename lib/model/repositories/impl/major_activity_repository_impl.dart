import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/major_activity_model.dart';
import '../../entities/major_activity.dart';
import '../major_activity_repository.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// Network-first repository for BQ 18 (`GET /analytics/major-activity/`),
/// falling back to the global `cached_responses` copy in SQLite when offline.
class MajorActivityRepositoryImpl implements MajorActivityRepository {
  static const String cacheOwner = 'global';
  static const String cacheKey = 'major_activity_bq18';

  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  MajorActivityRepositoryImpl({required this.remote, this.cache});

  @override
  Future<MajorActivityInsight> getMajorActivity() {
    final cache = this.cache;
    if (cache == null) {
      return guardRequest(() => remote.getMajorActivity());
    }
    return guardRequest(() async {
      final result = await cache.networkFirst(
        ownerId: cacheOwner,
        key: cacheKey,
        fetch: () async => MajorActivityModel.toJson(await remote.getMajorActivity()),
        parse: MajorActivityModel.fromJson,
      );
      return result.savedAt == null ? result.data : result.data.copyWith(savedAt: result.savedAt);
    });
  }
}
