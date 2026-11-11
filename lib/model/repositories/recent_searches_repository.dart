/// The searches a user made recently, saved on the phone so they are there offline and after the
/// app is closed. Each list is most recent first.
abstract class RecentSearchesRepository {
  /// The saved searches of [ownerId]. Never throws: if they cannot be read there are none.
  Future<List<String>> getAll(String ownerId);

  /// Saves [query] as the most recent one and returns the new list. A blank or one-letter query
  /// is not saved; a query already there (ignoring case) moves to the front.
  Future<List<String>> add(String ownerId, String query);

  /// Forgets [query] and returns the new list.
  Future<List<String>> remove(String ownerId, String query);

  Future<void> clear(String ownerId);
}
