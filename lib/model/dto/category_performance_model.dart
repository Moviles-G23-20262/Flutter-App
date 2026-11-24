import '../entities/category_performance.dart';

/// Parses GET /analytics/categories/:
/// `{"data": [{"category": "BOOKS", "total_listings": 12, "completed_exchanges": 4}]}`.
abstract final class CategoryPerformanceModel {
  /// Rows without a category are skipped; missing counts read as 0. The server order (most
  /// completed exchanges first) is kept.
  static List<CategoryPerformance> listFromJson(Object? json) {
    final rows = json is Map ? json['data'] : null;
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map && row['category'] is String && (row['category'] as String).isNotEmpty)
          CategoryPerformance(
            category: row['category'] as String,
            totalListings: (row['total_listings'] as num?)?.toInt() ?? 0,
            completedExchanges: (row['completed_exchanges'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// The copy saved on the phone; same shape as the server answer.
  static Map<String, dynamic> toJson(List<CategoryPerformance> categories) => {
        'data': [
          for (final c in categories)
            {
              'category': c.category,
              'total_listings': c.totalListings,
              'completed_exchanges': c.completedExchanges,
            },
        ],
      };
}
