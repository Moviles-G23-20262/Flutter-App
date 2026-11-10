import 'package:shared_preferences/shared_preferences.dart';

import '../listing_health_preferences_repository.dart';

/// Stores per-seller Listing Health Advisor settings in [SharedPreferences]:
/// - Chosen stale-listing threshold (`staleDays`: 7, 14, 21, or 30 days)
/// - Locally dismissed advisory listing IDs so hidden tips stay dismissed across restarts
class ListingHealthPreferencesRepositoryImpl implements ListingHealthPreferencesRepository {
  static String staleDaysKey(String ownerId) => 'listing_health_stale_days_$ownerId';
  static String dismissedIdsKey(String ownerId) => 'listing_health_dismissed_ids_$ownerId';

  final Future<SharedPreferences> Function() _prefs;

  ListingHealthPreferencesRepositoryImpl({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  @override
  Future<int> loadStaleDays(String ownerId) async {
    final p = await _prefs();
    final saved = p.getInt(staleDaysKey(ownerId));
    if (saved != null && ListingHealthPreferencesRepository.allowedStaleDays.contains(saved)) {
      return saved;
    }
    return ListingHealthPreferencesRepository.defaultStaleDays;
  }

  @override
  Future<void> saveStaleDays(String ownerId, int staleDays) async {
    final normalized = ListingHealthPreferencesRepository.allowedStaleDays.contains(staleDays)
        ? staleDays
        : ListingHealthPreferencesRepository.defaultStaleDays;
    final p = await _prefs();
    await p.setInt(staleDaysKey(ownerId), normalized);
  }

  @override
  Future<Set<String>> loadDismissedIds(String ownerId) async {
    final p = await _prefs();
    final list = p.getStringList(dismissedIdsKey(ownerId)) ?? const [];
    return list.toSet();
  }

  @override
  Future<void> saveDismissedIds(String ownerId, Set<String> ids) async {
    final p = await _prefs();
    final sorted = ids.toList()..sort();
    await p.setStringList(dismissedIdsKey(ownerId), sorted);
  }
}
