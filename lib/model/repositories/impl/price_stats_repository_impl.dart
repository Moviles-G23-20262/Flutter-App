import '../../entities/price_stats.dart';
import '../price_stats_repository.dart';
import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/expiring_lru_cache.dart';

/// Price statistics from the analytics service, remembered in memory for a while.
///
/// A seller trying a few categories and conditions while pricing asks for the same combination
/// again and again (and every ask is a request that can time out). So each answer is kept in an
/// [ExpiringLruCache]:
/// - [cacheSize] = 10: there are 5 categories x 4 conditions = 20 combinations, a seller looks at
///   a handful, and an entry is a few numbers, so half of the domain covers a session while the
///   least recently used combination is dropped first.
/// - [cacheTtl] = 10 minutes: the figures only change when a sale is completed, so ten minutes
///   of staleness is harmless, and a later session sees fresh numbers.
/// Only successful answers are kept: a failure is never cached, so the next ask tries the network.
class PriceStatsRepositoryImpl implements PriceStatsRepository {
  static const int cacheSize = 10;
  static const Duration cacheTtl = Duration(minutes: 10);

  final AnalyticsRemoteDataSource remote;
  final ExpiringLruCache<String, PriceStats> _cache;

  PriceStatsRepositoryImpl(
    this.remote, {
    ExpiringLruCache<String, PriceStats>? cache,
  }) : _cache = cache ?? ExpiringLruCache(maxSize: cacheSize, ttl: cacheTtl);

  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) async {
    final key = '$category|$condition';
    final saved = _cache.get(key);
    if (saved != null) return saved;
    final stats = await remote.getPriceStats(category: category, condition: condition);
    _cache.put(key, stats);
    return stats;
  }
}
