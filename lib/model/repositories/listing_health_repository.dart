import '../data_sources/local/response_cache.dart';
import '../entities/dead_listings_insight.dart';

/// Reads BQ 10 dead-listings analytics with two-level caching (LRU memory + SQLite).
abstract class ListingHealthRepository {
  Future<CachedResult<DeadListingsInsight>> getDeadListings({
    int staleDays = 14,
    String? sellerId,
  });
}
