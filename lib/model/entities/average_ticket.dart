import 'package:flutter/foundation.dart';

import 'material_entity.dart';

/// Average ticket (BQ14): what a completed campus sale is worth, in COP, overall and per
/// item condition. Lets a seller see how much the condition of an item moves its price.
@immutable
class AverageTicket {
  /// Mean price of every completed exchange; `null` while there are none.
  final int? globalAverage;

  /// Mean price per condition, best condition first. Conditions without sales are absent.
  final Map<MaterialConditionEnum, int> byCondition;

  const AverageTicket({required this.globalAverage, this.byCondition = const {}});

  static const empty = AverageTicket(globalAverage: null);

  bool get hasData => globalAverage != null;

  /// The highest per-condition average, to scale the breakdown bars.
  int get highestByCondition => byCondition.values.fold(0, (max, v) => v > max ? v : max);
}
