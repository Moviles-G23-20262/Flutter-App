import '../../entities/analytics_event.dart';
import '../analytics_event_repository.dart';
import '../../data_sources/analytics_event_remote_data_source.dart';

class AnalyticsEventRepositoryImpl implements AnalyticsEventRepository {
  final AnalyticsEventRemoteDataSource remote;

  AnalyticsEventRepositoryImpl(this.remote);

  @override
  Future<void> track(AnalyticsEvent event) => remote.send(event);
}
