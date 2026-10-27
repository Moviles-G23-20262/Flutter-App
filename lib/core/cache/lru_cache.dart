import 'dart:collection';

/// Generic in-memory Least Recently Used (LRU) cache built on [LinkedHashMap].
///
/// Reading an existing key moves it to the end (most recently used).
/// Inserting a new key when capacity is reached evicts the first key (least recently used).
/// All operations (get, put, remove, containsKey) run in O(1) time complexity.
class LruCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  LruCache({this.capacity = 40}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be greater than 0');
    }
  }

  /// Current number of cached items in memory.
  int get length => _map.length;

  /// Whether the cache contains an entry for [key].
  bool containsKey(K key) => _map.containsKey(key);

  /// Retrieves the value for [key] and marks it as most recently used.
  /// Returns `null` if the key is not present.
  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  /// Inserts or updates [key] with [value].
  /// If [key] already exists, it is updated and moved to the end.
  /// If inserting exceeds [capacity], the oldest (least recently used) entry is evicted.
  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity) {
      final oldestKey = _map.keys.first;
      _map.remove(oldestKey);
    }
    _map[key] = value;
  }

  /// Removes [key] from the cache. Returns the removed value or `null`.
  V? remove(K key) => _map.remove(key);

  /// Clears all entries from the memory cache.
  void clear() => _map.clear();
}
