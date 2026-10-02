import 'package:flutter/foundation.dart';

import 'material_entity.dart';

/// Where the listings of a search came from.
enum SearchSource {
  /// Fresh data fetched from the backend.
  online,

  /// Listings saved on the device by the last successful sync.
  offline,
}

/// What the student asked for: free text plus the active filters.
@immutable
class SearchCriteria {
  final String query;
  final MaterialCategoryEnum? category;
  final MaterialConditionEnum? condition;

  /// Upper price bound. `null` means "no limit".
  final double? maxPrice;

  const SearchCriteria({
    this.query = '',
    this.category,
    this.condition,
    this.maxPrice,
  });

  String get normalizedQuery => query.trim().toLowerCase();
  bool get hasQuery => normalizedQuery.isNotEmpty;
}

/// Listings saved on the device, with the moment they were synced.
@immutable
class CatalogSnapshot {
  final List<MaterialEntity> items;

  /// `null` when the catalog has never been synced.
  final DateTime? syncedAt;

  const CatalogSnapshot({required this.items, this.syncedAt});

  static const CatalogSnapshot empty = CatalogSnapshot(items: []);
}

/// Outcome of a search, independent of the strategy that produced it.
@immutable
class SearchResult {
  final List<MaterialEntity> items;
  final SearchSource source;

  /// Online: when the data was fetched. Offline: when the saved copy was synced
  /// (`null` if nothing was ever saved).
  final DateTime? syncedAt;

  /// `true` when the device looked online but the server failed, so the
  /// offline strategy answered instead.
  final bool serverUnreachable;

  const SearchResult({
    required this.items,
    required this.source,
    this.syncedAt,
    this.serverUnreachable = false,
  });

  bool get isOffline => source == SearchSource.offline;

  SearchResult copyWith({List<MaterialEntity>? items, bool? serverUnreachable}) {
    return SearchResult(
      items: items ?? this.items,
      source: source,
      syncedAt: syncedAt,
      serverUnreachable: serverUnreachable ?? this.serverUnreachable,
    );
  }
}
