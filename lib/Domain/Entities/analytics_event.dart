import 'enums.dart';

/// Something the user did that the analytics service wants to count.
class AnalyticsEvent {
  final AnalyticsEventType type;
  final String? materialId;
  final Map<String, dynamic>? metadata;
  final DateTime occurredAt;

  const AnalyticsEvent({
    required this.type,
    required this.occurredAt,
    this.materialId,
    this.metadata,
  });
}
