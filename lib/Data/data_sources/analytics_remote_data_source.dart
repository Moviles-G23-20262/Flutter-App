import '../../core/network/api_client.dart';
import '../Models/conversation_insight_model.dart';

/// Talks to the Django analytics service (a different base URL than the NestJS API).
class AnalyticsRemoteDataSource {
  final ApiClient apiClient;

  AnalyticsRemoteDataSource({required this.apiClient});

  Future<ConversationInsightModel> getConversationInsight() async {
    final json = await apiClient.get('/analytics/chat-to-meeting-point/');
    return ConversationInsightModel.fromJson(json as Map<String, dynamic>);
  }
}
