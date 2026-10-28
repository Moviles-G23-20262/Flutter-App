import 'enums.dart';

/// Something the user did that the analytics service wants to count.
class AnalyticsEvent {
  /// UUIDv4 made on the device. It travels with every retry, so the back-end can drop
  /// the copies of an event it already stored.
  final String clientId;
  final AnalyticsEventType type;
  final String? materialId;
  final Map<String, dynamic>? metadata;
  final DateTime occurredAt;

  /// When the device really created the event, even if it reaches the server much later.
  final DateTime clientCreatedAt;

  const AnalyticsEvent({
    required this.clientId,
    required this.type,
    required this.occurredAt,
    required this.clientCreatedAt,
    this.materialId,
    this.metadata,
  });

  /// The wire / disk format: one of these per line in `pending.jsonl`.
  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'eventType': type.name,
        if (materialId != null) 'materialId': materialId,
        if (metadata != null) 'metadata': metadata,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
      };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) => AnalyticsEvent(
        clientId: json['client_id'] as String,
        type: AnalyticsEventType.values.byName(json['eventType'] as String),
        materialId: json['materialId'] as String?,
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        clientCreatedAt: DateTime.parse(json['clientCreatedAt'] as String),
      );
}
