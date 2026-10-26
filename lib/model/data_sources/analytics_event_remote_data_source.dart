import '../../app/network/api_client.dart';
import '../entities/analytics_event.dart';

/// POST /analytics-events on the main API. [apiClient] adds the Bearer token when signed in.
class AnalyticsEventRemoteDataSource {
  final ApiClient apiClient;

  AnalyticsEventRemoteDataSource({required this.apiClient});

  Future<void> send(AnalyticsEvent event) async {
    await apiClient.post('/analytics-events', body: {
      'eventType': event.type.name,
      if (event.materialId != null) 'materialId': event.materialId,
      if (event.metadata != null) 'metadata': event.metadata,
      'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    });
  }
}
