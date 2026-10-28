import '../../app/network/api_client.dart';
import '../entities/analytics_event.dart';

/// POST /analytics-events/batch on the main API. [apiClient] adds the Bearer token when signed in.
class AnalyticsEventRemoteDataSource {
  final ApiClient apiClient;

  AnalyticsEventRemoteDataSource({required this.apiClient});

  /// Throws [NetworkException] / [ApiException] unless the server answers 2xx. Resending an
  /// event is safe: the server ignores a `client_id` it already stored.
  Future<void> sendBatch(List<AnalyticsEvent> events) async {
    await apiClient.post('/analytics-events/batch', body: {
      'events': [for (final event in events) event.toJson()],
    });
  }
}
