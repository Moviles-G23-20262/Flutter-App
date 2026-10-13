import '../Entities/analytics_event.dart';

abstract class AnalyticsEventRepository {
  /// Sends [event] to the back-end. Throws when it cannot be delivered.
  Future<void> track(AnalyticsEvent event);
}
