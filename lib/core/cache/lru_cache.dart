import 'dart:collection';

/// Bounded in-memory Least-Recently-Used (LRU) cache with optional per-entry TTL.
///
/// Backed by a [LinkedHashMap] so `get` and `put` both run in O(1) time:
/// accessing an entry moves it to the most-recently-used tail, and inserting past
/// [maxEntries] evicts the least-recently-used head.
class LruCache<K, V> {
  final int maxEntries;
  final Duration? ttl;
  final DateTime Function() _clock;

  final LinkedHashMap<K, _LruEntry<V>> _entries = LinkedHashMap<K, _LruEntry<V>>();

  int _hitCount = 0;
  int _missCount = 0;

  LruCache({
    required this.maxEntries,
    this.ttl,
    DateTime Function()? clock,
  })  : assert(maxEntries > 0, 'maxEntries must be positive'),
        _clock = clock ?? DateTime.now;

  int get length => _entries.length;
  int get hitCount => _hitCount;
  int get missCount => _missCount;

  /// Returns the cached value for [key] if present and unexpired, refreshing its recency.
  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      _missCount++;
      return null;
    }
    final maxAge = ttl;
    if (maxAge != null && _clock().difference(entry.storedAt) >= maxAge) {
      _missCount++;
      return null;
    }
    // Re-insert at the tail so this key is now the most recently used.
    _entries[key] = entry;
    _hitCount++;
    return entry.value;
  }

  /// Inserts or replaces [key] as the most-recently-used entry, evicting the oldest if full.
  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = _LruEntry<V>(value, _clock());
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Removes a single [key] if present.
  V? remove(K key) => _entries.remove(key)?.value;

  /// Evicts all entries.
  void clear() => _entries.clear();
}

class _LruEntry<V> {
  final V value;
  final DateTime storedAt;

  const _LruEntry(this.value, this.storedAt);
}
