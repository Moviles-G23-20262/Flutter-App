import 'lru_cache.dart';

/// An in-memory cache with two limits: it holds at most [maxSize] entries (the least recently
/// used one is dropped when a new one does not fit, see [LruCache]) and an entry is only good for
/// [ttl] after it was stored (a read after that finds nothing and forgets it).
///
/// The size limit bounds memory; the time limit bounds how stale a value can be. Use it for
/// answers that are cheap to keep but may change on the server, so a screen reopened soon after
/// does not repeat the request, and one reopened much later does.
///
/// The clock is injectable so tests do not have to wait for the time to pass.
class ExpiringLruCache<K, V> {
  final int maxSize;
  final Duration ttl;
  final DateTime Function() _now;
  final LruCache<K, _Timed<V>> _entries;

  ExpiringLruCache({required this.maxSize, required this.ttl, DateTime Function()? now})
      : assert(ttl > Duration.zero),
        _now = now ?? DateTime.now,
        _entries = LruCache(maxSize);

  /// Entries held, including ones that expired and were not read yet.
  int get length => _entries.length;

  /// The keys from least to most recently used.
  Iterable<K> get keys => _entries.keys;

  /// The value for [key], marking it as the most recently used. `null` when it is absent or
  /// expired (an expired entry is removed).
  V? get(K key) {
    final entry = _entries.get(key);
    if (entry == null) return null;
    if (!_now().isBefore(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Stores [value], valid for [ttl] from now, as the most recently used entry.
  void put(K key, V value) => _entries.put(key, _Timed(value, _now().add(ttl)));

  V? remove(K key) => _entries.remove(key)?.value;

  void clear() => _entries.clear();
}

class _Timed<V> {
  final V value;
  final DateTime expiresAt;

  const _Timed(this.value, this.expiresAt);
}
