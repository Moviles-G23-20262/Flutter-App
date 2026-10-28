import '../entities/analytics_event.dart';

abstract class AnalyticsEventRepository {
  /// Queues [event] on the device for a later upload. Throws when it cannot be stored.
  Future<void> track(AnalyticsEvent event);
}
