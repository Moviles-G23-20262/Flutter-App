import '../../data_sources/local/recent_searches_store.dart';
import '../recent_searches_repository.dart';

/// Recent searches in the Hive box of [RecentSearchesStore].
///
/// They are a convenience: losing one only means typing it again, so a storage error never
/// reaches the user (reads give an empty list, writes leave the list as it was).
class RecentSearchesRepositoryImpl implements RecentSearchesRepository {
  /// Only the latest searches are kept, so the list stays short enough to show.
  static const int maxSearches = 8;
  static const int minQueryLength = 2;

  final RecentSearchesStore store;

  RecentSearchesRepositoryImpl(this.store);

  @override
  Future<List<String>> getAll(String ownerId) async {
    try {
      return await store.read(ownerId);
    } on Object {
      return const [];
    }
  }

  @override
  Future<List<String>> add(String ownerId, String query) async {
    final text = query.trim();
    final current = await getAll(ownerId);
    if (text.length < minQueryLength) return current;
    final lower = text.toLowerCase();
    final updated = [text, for (final item in current) if (item.toLowerCase() != lower) item]
        .take(maxSearches)
        .toList(growable: false);
    return _save(ownerId, updated, current);
  }

  @override
  Future<List<String>> remove(String ownerId, String query) async {
    final lower = query.trim().toLowerCase();
    final current = await getAll(ownerId);
    final updated = [for (final item in current) if (item.toLowerCase() != lower) item];
    return _save(ownerId, updated, current);
  }

  @override
  Future<void> clear(String ownerId) async {
    try {
      await store.write(ownerId, const []);
    } on Object {
      // The old list stays; nothing to tell the user.
    }
  }

  Future<List<String>> _save(String ownerId, List<String> updated, List<String> fallback) async {
    try {
      await store.write(ownerId, updated);
      return updated;
    } on Object {
      return fallback;
    }
  }
}
