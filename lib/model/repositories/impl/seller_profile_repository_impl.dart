import '../../../app/network/api_client.dart';
import '../../../core/cache/lru_cache.dart';
import '../../../core/isolates/seller_profile_aggregator.dart';
import '../../data_sources/local/seller_profile_store.dart';
import '../../data_sources/marketplace_remote_data_source.dart';
import '../../dto/marketplace_models.dart';
import '../../entities/material_entity.dart';
import '../../entities/rating_entity.dart';
import '../../entities/seller_profile_entity.dart';
import '../../entities/seller_reputation.dart';
import '../../entities/user_summary.dart';
import '../../exceptions/data_exceptions.dart';
import '../seller_profile_repository.dart';
import '../seller_reputation_repository.dart';

/// Coordinates all 4 Sprint 4 strategies for the Seller Profile screen:
///
/// 1. **Caching (L1):** In-memory [LruCache] (capacity 20 sellers, 2-minute TTL) so reopening
///    a recently viewed seller answers immediately with 0 network and 0 SQLite calls.
///    Pull-to-refresh (`forceRefresh: true`) bypasses this layer.
/// 2. **Multi-threading:** Parallel network requests (`Future.wait`) for ratings, listings, and
///    BQ 17 reputation, followed by off-main-thread `Isolate.run` aggregation for star distribution,
///    top 3 tags ("Buyers say"), and active/sold counts.
/// 3. **Local Storage (L2):** Dedicated SQLite `seller_profiles` table (`AppDatabase` v4) managed
///    by [SellerProfileStore], pruning rows past the 30 most recent sellers in one transaction.
/// 4. **Eventual Connectivity:** Network-first with graceful fallback to the saved SQLite snapshot
///    (marking `savedAt` so the UI displays `SavedCopyBanner`), or a clear offline exception if the
///    seller was never opened before.
class SellerProfileRepositoryImpl implements SellerProfileRepository {
  static const int memoryCacheCapacity = 20;
  static const Duration memoryCacheTtl = Duration(minutes: 2);

  final MarketplaceRemoteDataSource remote;
  final SellerProfileStore store;
  final SellerReputationRepository? reputationRepository;
  final LruCache<String, SellerProfileData> _memoryCache;

  SellerProfileRepositoryImpl({
    required this.remote,
    required this.store,
    this.reputationRepository,
    LruCache<String, SellerProfileData>? memoryCache,
    DateTime Function()? clock,
  }) : _memoryCache = memoryCache ??
            LruCache<String, SellerProfileData>(
              maxEntries: memoryCacheCapacity,
              ttl: memoryCacheTtl,
              clock: clock,
            );

  /// Exposed for diagnostics & benchmarks.
  int get memoryCacheHits => _memoryCache.hitCount;
  int get memoryCacheMisses => _memoryCache.missCount;
  int get memoryCacheSize => _memoryCache.length;

  @override
  void clearMemoryCache() => _memoryCache.clear();

  @override
  Future<SellerProfileData> getSellerProfile(
    UserSummary seller, {
    List<MaterialEntity>? knownMaterials,
    bool forceRefresh = false,
  }) async {
    // L1: In-memory LRU cache (20 entries, 2-minute TTL). Skipped on pull-to-refresh.
    if (!forceRefresh) {
      final cached = _memoryCache.get(seller.id);
      if (cached != null) {
        return cached.copyWith(fromMemoryCache: true);
      }
    }

    // Fetch BQ 17 reputation concurrently; never block or fail Seller Profile if analytics is down.
    final reputationFuture = _fetchReputationSafely();

    try {
      // Parallel network fetches: seller's ratings + listings (if not supplied or refreshing).
      final ratingsFuture = remote.getRatingsForUser(seller.id);
      final shouldFetchMaterials = knownMaterials == null || forceRefresh;
      final listingsFuture = shouldFetchMaterials
          ? remote.getMaterials().then(
                (all) => all.where((m) => m.sellerId == seller.id).toList(growable: false),
              )
          : Future.value(
              knownMaterials.where((m) => m.sellerId == seller.id).toList(growable: false),
            );

      final results = await Future.wait<Object?>([
        ratingsFuture,
        listingsFuture,
        reputationFuture,
      ]);

      final ratings = results[0]! as List<RatingEntity>;
      final sellerListings = results[1]! as List<MaterialEntity>;
      final reputation = results[2] as SellerReputationInsight?;

      // Off-main-thread aggregation via Isolate.run (MO6).
      final summary = await aggregateSellerProfileInIsolate(
        SellerProfileAggregationInput(
          reviews: ratings,
          sellerListings: sellerListings,
          fallbackRating: seller.rating,
        ),
      );

      // L2: Persist snapshot in SQLite `seller_profiles` (atomic upsert + prune > 30).
      await store.save(seller.id, _encodeSnapshot(seller, ratings, sellerListings));

      final profile = SellerProfileData(
        seller: seller,
        summary: summary,
        reputation: reputation,
        savedAt: null,
        fromMemoryCache: false,
      );
      _memoryCache.put(seller.id, profile);
      return profile;
    } on NetworkException {
      return _readOfflineFallback(seller, reputationFuture);
    } on ApiException catch (e) {
      // If the server returned 5xx, also check if we have a saved snapshot so the user isn't blocked.
      if (e.statusCode >= 500) {
        final fallback = await _tryReadStoredProfile(seller, reputationFuture);
        if (fallback != null) return fallback;
      }
      throw DataException(e.message);
    }
  }

  Future<SellerReputationInsight?> _fetchReputationSafely() async {
    final repo = reputationRepository;
    if (repo == null) return null;
    try {
      return await repo.getSellerReputation();
    } catch (_) {
      return null;
    }
  }

  Future<SellerProfileData> _readOfflineFallback(
    UserSummary seller,
    Future<SellerReputationInsight?> reputationFuture,
  ) async {
    final fallback = await _tryReadStoredProfile(seller, reputationFuture);
    if (fallback != null) return fallback;
    throw const NoConnectionException();
  }

  Future<SellerProfileData?> _tryReadStoredProfile(
    UserSummary seller,
    Future<SellerReputationInsight?> reputationFuture,
  ) async {
    final stored = await store.read(seller.id);
    if (stored == null) return null;
    try {
      final decodedSeller = stored.body['seller'] is Map<String, dynamic>
          ? userSummaryFromJson(stored.body['seller'] as Map<String, dynamic>)
          : seller;
      final ratings = parseList(stored.body['ratings'] ?? const [], ratingFromJson);
      final listings = parseList(stored.body['listings'] ?? const [], materialFromJson);
      final reputation = await reputationFuture;

      final summary = await aggregateSellerProfileInIsolate(
        SellerProfileAggregationInput(
          reviews: ratings,
          sellerListings: listings,
          fallbackRating: decodedSeller.rating,
        ),
      );

      return SellerProfileData(
        seller: decodedSeller,
        summary: summary,
        reputation: reputation,
        savedAt: stored.savedAt,
        fromMemoryCache: false,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _encodeSnapshot(
    UserSummary seller,
    List<RatingEntity> ratings,
    List<MaterialEntity> listings,
  ) =>
      {
        'seller': _userSummaryToJson(seller),
        'ratings': [for (final r in ratings) _ratingToJson(r)],
        'listings': [for (final m in listings) _materialToJson(m)],
      };

  static Map<String, dynamic> _userSummaryToJson(UserSummary u) => {
        'id': u.id,
        'fullName': u.fullName,
        'major': u.major,
        'faculty': u.faculty,
        'rating': u.rating,
      };

  static Map<String, dynamic> _ratingToJson(RatingEntity r) => {
        'id': r.id,
        'exchangeId': r.exchangeId,
        'raterId': r.raterId,
        'ratedId': r.ratedId,
        'stars': r.stars,
        'tags': r.tags,
        'review': r.review,
        'createdAt': r.createdAt.toUtc().toIso8601String(),
        if (r.rater != null) 'rater': _userSummaryToJson(r.rater!),
      };

  static Map<String, dynamic> _materialToJson(MaterialEntity m) => {
        'id': m.id,
        'title': m.title,
        'description': m.description,
        'courseCode': m.courseCode,
        'price': m.price.toStringAsFixed(2),
        'condition': m.condition?.name,
        'status': m.status.name,
        'edition': m.edition,
        'model': m.model,
        'imageUrls': m.imageUrls,
        'sellerId': m.sellerId,
        if (m.seller != null) 'seller': _userSummaryToJson(m.seller!),
        'category': m.category.name,
        'createdAt': m.createdAt.toUtc().toIso8601String(),
        'updatedAt': m.updatedAt.toUtc().toIso8601String(),
      };
}
