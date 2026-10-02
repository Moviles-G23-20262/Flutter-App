import '../Entities/material_entity.dart';
import '../Entities/search_models.dart';

/// Pure helpers shared by every [SearchStrategy].
abstract final class ListingSearchRules {
  /// Category, condition and price filters (the query is handled per strategy).
  static bool passesFilters(MaterialEntity material, SearchCriteria criteria) {
    if (criteria.category != null && material.category != criteria.category) {
      return false;
    }
    if (criteria.condition != null && material.condition != criteria.condition) {
      return false;
    }
    final maxPrice = criteria.maxPrice;
    if (maxPrice != null && material.price > maxPrice) return false;
    return true;
  }

  /// Lower-cased words of [raw].
  static List<String> tokenize(String raw) {
    return raw
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Letters and digits only, so "ECON-1101", "econ 1101" and "econ1101" match.
  static String compact(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Most recently created first.
  static int newestFirst(MaterialEntity a, MaterialEntity b) {
    return b.createdAt.compareTo(a.createdAt);
  }
}
