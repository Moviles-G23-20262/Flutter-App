import 'dart:collection';

/// A fixed-size in-memory cache that drops the least recently used entry when full.
///
/// Built on a [LinkedHashMap], which keeps insertion order: every read or write moves the
/// entry to the end, so the first entry is always the least recently used one.
class LruCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  LruCache(this.capacity) : assert(capacity > 0);

  int get length => _entries.length;

  /// The keys from least to most recently used.
  Iterable<K> get keys => _entries.keys;

  bool containsKey(K key) => _entries.containsKey(key);

  /// The value for [key], marking it as the most recently used. `null` when absent.
  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
  }

  V? remove(K key) => _entries.remove(key);

  /// Removes every entry whose key matches [test].
  void removeWhere(bool Function(K key) test) => _entries.removeWhere((key, _) => test(key));

  void clear() => _entries.clear();
}
