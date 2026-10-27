import 'package:sqflite/sqflite.dart';
import '../../core/cache/lru_cache.dart';
import '../../core/isolates/response_codec.dart';
import 'app_database.dart';

/// Represents a cached server response retrieved from memory or local SQLite storage.
class CachedResponse {
  final dynamic data;
  final DateTime savedAt;

  CachedResponse({required this.data, required this.savedAt});

  /// Age of the cached copy.
  Duration get age => DateTime.now().difference(savedAt);

  /// Human-readable age string for offline banners (e.g., "5 min ago", "2 hours ago").
  String get formattedAge {
    final minutes = age.inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes == 1) return '1 min ago';
    if (minutes < 60) return '$minutes min ago';
    final hours = age.inHours;
    if (hours == 1) return '1 hour ago';
    if (hours < 24) return '$hours hours ago';
    final days = age.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }
}

/// Two-level response cache: In-memory [LruCache] in front of persistent [AppDatabase] SQLite table.
class ResponseCache {
  final AppDatabase appDatabase;
  final LruCache<String, CachedResponse> memoryCache;

  ResponseCache({
    required this.appDatabase,
    LruCache<String, CachedResponse>? memoryCache,
  }) : memoryCache = memoryCache ?? LruCache<String, CachedResponse>(capacity: 40);

  static String buildKey({required String userId, required String endpoint}) =>
      '$userId:$endpoint';

  /// Reads cached response for [userId] and [endpoint].
  /// Checks memory LRU first for instant return, then falls back to SQLite.
  Future<CachedResponse?> read({
    required String userId,
    required String endpoint,
  }) async {
    final key = buildKey(userId: userId, endpoint: endpoint);

    // 1. Check in-memory LRU cache first (O(1))
    final inMemory = memoryCache.get(key);
    if (inMemory != null) {
      return inMemory;
    }

    // 2. Fall back to local SQLite database
    try {
      final db = await appDatabase.database;
      final rows = await db.query(
        'cached_responses',
        where: 'cache_key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      final row = rows.first;
      final rawJson = row['response_json'] as String;
      final savedAtMs = row['saved_at'] as int;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);

      // Decode using background isolate to prevent UI frame drops
      final decodedData = await ResponseCodec.decode(rawJson);
      final cached = CachedResponse(data: decodedData, savedAt: savedAt);

      // Populate memory cache
      memoryCache.put(key, cached);
      return cached;
    } catch (_) {
      return null;
    }
  }

  /// Saves a successful server response into both in-memory LRU and SQLite.
  Future<void> write({
    required String userId,
    required String endpoint,
    required dynamic data,
  }) async {
    final key = buildKey(userId: userId, endpoint: endpoint);
    final now = DateTime.now();
    final cached = CachedResponse(data: data, savedAt: now);

    // 1. Store in memory LRU cache immediately
    memoryCache.put(key, cached);

    // 2. Persist to SQLite in background isolate
    try {
      final jsonString = await ResponseCodec.encode(data);
      final db = await appDatabase.database;

      await db.insert(
        'cached_responses',
        {
          'cache_key': key,
          'user_id': userId,
          'endpoint': endpoint,
          'response_json': jsonString,
          'saved_at': now.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Writing cache should never crash the app
    }
  }

  /// Evicts cached response for a specific user and endpoint.
  Future<void> evict({required String userId, required String endpoint}) async {
    final key = buildKey(userId: userId, endpoint: endpoint);
    memoryCache.remove(key);
    try {
      final db = await appDatabase.database;
      await db.delete(
        'cached_responses',
        where: 'cache_key = ?',
        whereArgs: [key],
      );
    } catch (_) {}
  }

  /// Clears in-memory cache (e.g. on user sign-out or memory pressure).
  void clearMemory() {
    memoryCache.clear();
  }
}
