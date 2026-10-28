import '../../data_sources/analytics_remote_data_source.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/conversation_insight_model.dart';
import '../../entities/conversation_insight.dart';
import '../conversation_insight_repository.dart';

class ConversationInsightRepositoryImpl implements ConversationInsightRepository {
  final AnalyticsRemoteDataSource remoteDataSource;
  final ResponseCache? cache;

  ConversationInsightRepositoryImpl({required this.remoteDataSource, this.cache});

  @override
  Future<ConversationInsight> getConversationInsight() async {
    try {
      final insight = await remoteDataSource.getConversationInsight();
      if (cache != null) {
        await cache!.save(
          'global',
          'insight',
          insight.toJson(),
        );
      }
      return insight;
    } catch (e) {
      if (cache != null) {
        final cached = await cache!.read('global', 'insight');
        if (cached != null && cached.data is Map<String, dynamic>) {
          return ConversationInsightModel.fromJson(cached.data as Map<String, dynamic>);
        }
      }
      rethrow;
    }
  }
}
