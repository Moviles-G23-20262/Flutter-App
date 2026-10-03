import '../../core/network/api_client.dart';
import '../../Domain/Entities/meeting_point_density.dart';
import '../Models/conversation_insight_model.dart';
import '../Models/meeting_point_density_model.dart';

/// Talks to the Django analytics service (a different base URL than the NestJS API).
class AnalyticsRemoteDataSource {
  final ApiClient apiClient;

  AnalyticsRemoteDataSource({required this.apiClient});

  Future<ConversationInsightModel> getConversationInsight() async {
    final json = await apiClient.get('/analytics/chat-to-meeting-point/');
    return ConversationInsightModel.fromJson(json as Map<String, dynamic>);
  }

  /// BQ12: confirmed exchanges per campus meeting point and hour of the day.
  Future<MeetingPointDensity> getMeetingPointDensity() async {
    final json = await apiClient.get('/analytics/meeting-points/');
    return MeetingPointDensityModel.fromJson(json as Map<String, dynamic>);
  }
}
