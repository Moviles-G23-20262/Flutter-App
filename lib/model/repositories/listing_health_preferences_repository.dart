/// Persistent user preferences for the Listing Health & Price-Drop Advisor (SharedPreferences).
abstract class ListingHealthPreferencesRepository {
  static const int defaultStaleDays = 14;
  static const List<int> allowedStaleDays = [7, 14, 21, 30];

  Future<int> loadStaleDays(String ownerId);
  Future<void> saveStaleDays(String ownerId, int staleDays);

  Future<Set<String>> loadDismissedIds(String ownerId);
  Future<void> saveDismissedIds(String ownerId, Set<String> ids);
}
