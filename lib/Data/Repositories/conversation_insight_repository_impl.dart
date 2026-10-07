import '../../Domain/Entities/conversation_insight.dart';
import '../../Domain/repositories/conversation_insight_repository.dart';
import '../data_sources/analytics_remote_data_source.dart';

class ConversationInsightRepositoryImpl implements ConversationInsightRepository {
  final AnalyticsRemoteDataSource remoteDataSource;

  ConversationInsightRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ConversationInsight> getConversationInsight() => remoteDataSource.getConversationInsight();
}
