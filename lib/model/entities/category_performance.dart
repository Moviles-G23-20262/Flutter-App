import 'package:flutter/foundation.dart';

import 'material_entity.dart';

/// BQ6: how one item category does on the marketplace: how many listings it got and how many of
/// them ended in a completed exchange.
@immutable
class CategoryPerformance {
  /// The category as the server names it (`BOOKS`, `CALCULATORS`…).
  final String category;
  final int totalListings;
  final int completedExchanges;

  const CategoryPerformance({
    required this.category,
    required this.totalListings,
    required this.completedExchanges,
  });

  /// "Lab Equipment" for a category this app knows; otherwise the server name, readable.
  String get displayName {
    for (final known in MaterialCategoryEnum.values) {
      if (known.name == category) return known.displayName;
    }
    final words = category.toLowerCase().split('_').where((w) => w.isNotEmpty);
    return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  /// Share of the listings that ended in a completed exchange, from 0 to 1.
  double get completionRate => totalListings == 0 ? 0 : (completedExchanges / totalListings).clamp(0, 1).toDouble();
}
