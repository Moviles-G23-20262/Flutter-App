import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/time_to_sell_model.dart';
import '../../entities/time_to_sell.dart';
import '../time_to_sell_repository.dart';

class TimeToSellRepositoryImpl implements TimeToSellRepository {
  final AnalyticsRemoteDataSource remote;
  final ResponseCache? cache;

  static const String _cacheOwner = 'global';
  static const String _cacheKey = 'time_to_sell_bq11';

  TimeToSellRepositoryImpl({required this.remote, this.cache});

  @override
  Future<TimeToSellInsight> getTimeToSell() async {
    try {
      final model = await remote.getTimeToSell();
      if (cache != null) {
        await cache!.save(_cacheOwner, _cacheKey, model.toJson());
      }
      return model;
    } catch (_) {
      if (cache != null) {
        final cached = await cache!.read(_cacheOwner, _cacheKey);
        if (cached != null && cached.data is Map<String, dynamic>) {
          return TimeToSellModel.fromJson(cached.data as Map<String, dynamic>);
        }
      }
      return TimeToSellInsight.empty;
    }
  }
}
