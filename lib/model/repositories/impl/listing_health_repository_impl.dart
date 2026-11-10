import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/dead_listings_model.dart';
import '../../entities/dead_listings_insight.dart';
import '../listing_health_repository.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// Network-first BQ 10 repository backed by [ResponseCache] (LruCache + SQLite `cached_responses`).
///
/// Scopes cache keys by `sellerId ?? 'global'` and `staleDays` so each seller's risk profile
/// and threshold setting remains available offline with a timestamp for [OfflineBanner.forCache].
class ListingHealthRepositoryImpl implements ListingHealthRepository {
  static const String cacheKeyPrefix = 'dead_listings_bq10';

  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  ListingHealthRepositoryImpl({required this.remote, this.cache});

  @override
  Future<CachedResult<DeadListingsInsight>> getDeadListings({
    int staleDays = 14,
    String? sellerId,
  }) {
    final cache = this.cache;
    if (cache == null) {
      return guardRequest(() async => CachedResult.fresh(
            await remote.getDeadListings(staleDays: staleDays, sellerId: sellerId),
          ));
    }

    final owner = (sellerId != null && sellerId.isNotEmpty) ? sellerId : 'global';
    final key = '${cacheKeyPrefix}_$staleDays';

    return guardRequest(
      () => cache.networkFirst<DeadListingsInsight>(
        ownerId: owner,
        key: key,
        fetch: () async => DeadListingsModel.toJson(
          await remote.getDeadListings(staleDays: staleDays, sellerId: sellerId),
        ),
        parse: (json) => DeadListingsModel.fromJson(json as Map<String, dynamic>),
      ),
    );
  }
}
