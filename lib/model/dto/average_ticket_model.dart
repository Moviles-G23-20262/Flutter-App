import '../entities/average_ticket.dart';
import '../entities/material_entity.dart';

class AverageTicketModel extends AverageTicket {
  const AverageTicketModel({required super.globalAverage, super.byCondition});

  /// Parses GET /analytics/average-ticket/:
  /// `{"globalAverage": 45000, "byCondition": {"NEW": 60000, "GOOD": 30000}}`.
  /// Conditions this app version doesn't know are skipped.
  factory AverageTicketModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['byCondition'] as Map?) ?? const {};
    return AverageTicketModel(
      globalAverage: (json['globalAverage'] as num?)?.round(),
      byCondition: {
        for (final condition in MaterialConditionEnum.values)
          if (raw[condition.name] is num) condition: (raw[condition.name] as num).round(),
      },
    );
  }

  /// The copy saved on the phone; same shape as the server answer.
  static Map<String, dynamic> toJson(AverageTicket ticket) => {
        'globalAverage': ticket.globalAverage,
        'byCondition': {for (final e in ticket.byCondition.entries) e.key.name: e.value},
      };
}
