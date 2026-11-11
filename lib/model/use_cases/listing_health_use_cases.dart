import '../data_sources/local/response_cache.dart';
import '../entities/dead_listings_insight.dart';
import '../repositories/listing_health_preferences_repository.dart';
import '../repositories/listing_health_repository.dart';

/// Fetches BQ 10 dead-listing insights (network-first with SQLite + LRU cache fallback).
class GetDeadListingsInsightUseCase {
  final ListingHealthRepository repository;

  GetDeadListingsInsightUseCase(this.repository);

  Future<CachedResult<DeadListingsInsight>> execute({
    int staleDays = ListingHealthPreferencesRepository.defaultStaleDays,
    String? sellerId,
  }) =>
      repository.getDeadListings(staleDays: staleDays, sellerId: sellerId);
}

/// Loads local preferences (`staleDays` sensitivity and dismissed alert IDs) for [ownerId].
class LoadListingHealthPreferencesUseCase {
  final ListingHealthPreferencesRepository repository;

  LoadListingHealthPreferencesUseCase(this.repository);

  Future<({int staleDays, Set<String> dismissedIds})> execute(String ownerId) async {
    final staleDays = await repository.loadStaleDays(ownerId);
    final dismissedIds = await repository.loadDismissedIds(ownerId);
    return (staleDays: staleDays, dismissedIds: dismissedIds);
  }
}

/// Persists the seller's preferred stale-listing threshold in SharedPreferences.
class SaveListingHealthStaleDaysUseCase {
  final ListingHealthPreferencesRepository repository;

  SaveListingHealthStaleDaysUseCase(this.repository);

  Future<void> execute(String ownerId, int staleDays) =>
      repository.saveStaleDays(ownerId, staleDays);
}

/// Persists dismissed/restored health alerts in SharedPreferences.
class SaveDismissedHealthAlertsUseCase {
  final ListingHealthPreferencesRepository repository;

  SaveDismissedHealthAlertsUseCase(this.repository);

  Future<void> execute(String ownerId, Set<String> dismissedIds) =>
      repository.saveDismissedIds(ownerId, dismissedIds);
}
