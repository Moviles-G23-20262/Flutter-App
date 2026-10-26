import '../../app/network/api_client.dart';
import '../entities/meeting_point_density.dart';
import '../entities/price_stats.dart';
import '../dto/conversation_insight_model.dart';
import '../dto/price_stats_model.dart';
import '../dto/meeting_point_density_model.dart';

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

  /// Smart feature: price statistics of completed sales for a category and condition.
  Future<PriceStats> getPriceStats({required String category, required String condition}) async {
    final query = Uri(queryParameters: {'category': category, 'condition': condition}).query;
    final json = await apiClient.get('/analytics/price-stats/?$query');
    return PriceStatsModel.fromJson(json as Map<String, dynamic>);
  }
}
