import '../rules/client_id.dart';
import '../entities/analytics_event.dart';
import '../entities/enums.dart';
import '../repositories/analytics_event_repository.dart';

/// Records a user event (LISTING_VIEW, CONTACT_SELLER, ...) for analytics.
///
/// Fire and forget: callers do not need to await it, and it never throws. A lost event
/// (no network, server error, signed-out user) is simply dropped, so telemetry can never
/// get in the way of the user.
class TrackEventUseCase {
  final AnalyticsEventRepository repository;
  final DateTime Function() _now;

  TrackEventUseCase(this.repository, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  Future<void> execute(
    AnalyticsEventType type, {
    String? materialId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = _now();
      await repository.track(AnalyticsEvent(
        clientId: newClientId(),
        type: type,
        materialId: materialId,
        metadata: metadata,
        occurredAt: now,
        clientCreatedAt: now,
      ));
    } catch (_) {
      // Telemetry is best effort.
    }
  }
}
