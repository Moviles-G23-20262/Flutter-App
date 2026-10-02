import 'dart:math' as math;

import '../Entities/material_entity.dart';
import '../Entities/search_models.dart';
import '../repositories/material_catalog_repository.dart';
import '../rules/listing_search_rules.dart';

/// Strategy contract for finding listings that match a [SearchCriteria].
///
/// Two interchangeable algorithms implement it: [OnlineSearchStrategy] (fresh
/// data, ranked by relevance) and [OfflineSearchStrategy] (saved copy, plain
/// keyword match). `SearchMaterialsUseCase` picks one at runtime, so the screen
/// never needs to know which one answered.
abstract class SearchStrategy {
  const SearchStrategy();

  SearchSource get source;

  /// Returns the listings that match [criteria]. Implementations must not
  /// mutate shared state other than their own data source.
  Future<SearchResult> search(SearchCriteria criteria);
}

/// Used when the device is online.
///
/// Downloads the current catalog and ranks the matches by course-aware
/// relevance: an exact course code (ignoring dashes and spaces) beats a title
/// match, which beats a model, category or description match. Every word of the
/// query must match somewhere.
class OnlineSearchStrategy extends SearchStrategy {
  final MaterialCatalogRepository catalog;

  const OnlineSearchStrategy(this.catalog);

  @override
  SearchSource get source => SearchSource.online;

  @override
  Future<SearchResult> search(SearchCriteria criteria) async {
    final listings = await catalog.fetchRemote();
    final candidates = listings
        .where((m) => ListingSearchRules.passesFilters(m, criteria))
        .toList();

    final List<MaterialEntity> ordered;
    if (!criteria.hasQuery) {
      ordered = candidates..sort(ListingSearchRules.newestFirst);
    } else {
      final tokens = ListingSearchRules.tokenize(criteria.query);
      final wholeCode = ListingSearchRules.compact(criteria.query);
      final scored = <_ScoredListing>[];
      for (final listing in candidates) {
        final score = _score(listing, tokens, wholeCode, criteria.normalizedQuery);
        if (score != null) scored.add(_ScoredListing(listing, score));
      }
      scored.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0
            ? byScore
            : ListingSearchRules.newestFirst(a.listing, b.listing);
      });
      ordered = scored.map((s) => s.listing).toList();
    }

    return SearchResult(
      items: ordered,
      source: SearchSource.online,
      syncedAt: DateTime.now(),
    );
  }

  /// `null` when some word of the query matches nothing in the listing.
  double? _score(
    MaterialEntity listing,
    List<String> tokens,
    String wholeCode,
    String fullQuery,
  ) {
    final title = listing.title.toLowerCase();
    final code = ListingSearchRules.compact(listing.courseCode ?? '');
    final model = '${listing.model ?? ''} ${listing.edition ?? ''}'.toLowerCase();
    final category = listing.category.displayName.toLowerCase();
    final description = listing.description.toLowerCase();

    var score = 0.0;
    if (wholeCode.isNotEmpty && code == wholeCode) score += 6;
    if (tokens.length > 1 && title.contains(fullQuery)) score += 2;

    for (final token in tokens) {
      final compactToken = ListingSearchRules.compact(token);
      var best = 0.0;
      if (code.isNotEmpty && compactToken.isNotEmpty && code.contains(compactToken)) {
        best = math.max(best, 3.0);
      }
      if (title.contains(token)) best = math.max(best, 2.0);
      if (model.contains(token)) best = math.max(best, 1.5);
      if (category.contains(token)) best = math.max(best, 1.0);
      if (description.contains(token)) best = math.max(best, 0.5);
      if (best == 0) return null;
      score += best;
    }
    return score;
  }
}

class OfflineSearchStrategy extends SearchStrategy {
  final MaterialCatalogRepository catalog;

  const OfflineSearchStrategy(this.catalog);

  @override
  SearchSource get source => SearchSource.offline;

  @override
  Future<SearchResult> search(SearchCriteria criteria) async {
    final snapshot = await catalog.readLocal();
    final tokens = ListingSearchRules.tokenize(criteria.query);

    final matches = snapshot.items.where((listing) {
      if (!ListingSearchRules.passesFilters(listing, criteria)) return false;
      if (tokens.isEmpty) return true;
      final title = listing.title.toLowerCase();
      final code = ListingSearchRules.compact(listing.courseCode ?? '');
      final category = listing.category.displayName.toLowerCase();
      return tokens.every((token) {
        final compactToken = ListingSearchRules.compact(token);
        return title.contains(token) ||
            category.contains(token) ||
            (compactToken.isNotEmpty && code.contains(compactToken));
      });
    }).toList()
      ..sort(ListingSearchRules.newestFirst);

    return SearchResult(
      items: matches,
      source: SearchSource.offline,
      syncedAt: snapshot.syncedAt,
    );
  }
}

class _ScoredListing {
  final MaterialEntity listing;
  final double score;

  const _ScoredListing(this.listing, this.score);
}
