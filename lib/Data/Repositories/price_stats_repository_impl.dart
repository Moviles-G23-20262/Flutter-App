import '../../Domain/Entities/price_stats.dart';
import '../../Domain/repositories/price_stats_repository.dart';
import '../data_sources/analytics_remote_data_source.dart';

class PriceStatsRepositoryImpl implements PriceStatsRepository {
  final AnalyticsRemoteDataSource remote;

  PriceStatsRepositoryImpl(this.remote);

  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) =>
      remote.getPriceStats(category: category, condition: condition);
}
