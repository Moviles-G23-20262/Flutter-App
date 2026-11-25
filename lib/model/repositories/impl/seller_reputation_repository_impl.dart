import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/seller_reputation_model.dart';
import '../../entities/seller_reputation.dart';
import '../seller_reputation_repository.dart';
import 'marketplace_repositories_impl.dart' show guardRequest;

/// Network-first repository for BQ 17 (`GET /analytics/seller-reputation/`),
/// falling back to the global `cached_responses` copy when offline.
class SellerReputationRepositoryImpl implements SellerReputationRepository {
  static const String cacheOwner = 'global';
  static const String cacheKey = 'seller_reputation_bq17';

  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  SellerReputationRepositoryImpl({required this.remote, this.cache});

  @override
  Future<SellerReputationInsight> getSellerReputation() {
    final cache = this.cache;
    if (cache == null) {
      return guardRequest(() => remote.getSellerReputation());
    }
    return guardRequest(() async {
      final result = await cache.networkFirst(
        ownerId: cacheOwner,
        key: cacheKey,
        fetch: () async => SellerReputationModel.toJson(await remote.getSellerReputation()),
        parse: SellerReputationModel.fromJson,
      );
      return result.savedAt == null ? result.data : result.data.copyWith(savedAt: result.savedAt);
    });
  }
}
