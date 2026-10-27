import 'dart:convert';
import 'dart:isolate';

import 'package:sqflite/sqflite.dart';

import '../../../app/network/api_client.dart';
import 'app_database.dart';
import 'lru_cache.dart';

/// A saved server answer and when it was saved.
class CachedJson {
  final Object? data;
  final DateTime savedAt;

  const CachedJson(this.data, this.savedAt);
}

/// The answer of [ResponseCache.networkFirst]: fresh from the server, or the saved copy.
class CachedResult<T> {
  final T data;

  /// When the copy was saved; `null` when [data] just came from the server.
  final DateTime? savedAt;

  const CachedResult.fresh(this.data) : savedAt = null;
  const CachedResult.saved(this.data, DateTime this.savedAt);

  bool get fromCache => savedAt != null;
}

/// The last server answer per user and screen, in two levels: an [LruCache] in memory in front
/// of the `cached_responses` table. Reopening a screen reads memory; after a restart it reads
/// the database. Only the memory copy is ever evicted.
class ResponseCache {
  /// Saved answers longer than this many characters are decoded in a background isolate, and
  /// lists longer than [isolateListLength] are encoded there, so a long list never freezes the UI.
  static const int isolateThreshold = 64 * 1024;
  static const int isolateListLength = 100;

  final AppDatabase _db;
  final LruCache<String, CachedJson> _memory;
  final DateTime Function() _now;

  ResponseCache(this._db, {int memoryCapacity = 32, DateTime Function()? now})
      : _memory = LruCache(memoryCapacity),
        _now = now ?? DateTime.now;

  static String _memoryKey(String ownerId, String key) => '$ownerId\u0000$key';

  /// Replaces the saved copy of [key] for [ownerId].
  Future<void> save(String ownerId, String key, Object? data) async {
    final entry = CachedJson(data, _now());
    _memory.put(_memoryKey(ownerId, key), entry);
    final body = await _encode(data);
    final db = await _db.database;
    await db.insert(
      'cached_responses',
      {'owner_id': ownerId, 'cache_key': key, 'body': body, 'saved_at': entry.savedAt.millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The saved copy of [key] for [ownerId], or `null` if there is none.
  Future<CachedJson?> read(String ownerId, String key) async {
    final memoryKey = _memoryKey(ownerId, key);
    final inMemory = _memory.get(memoryKey);
    if (inMemory != null) return inMemory;

    final db = await _db.database;
    final rows = await db.query(
      'cached_responses',
      columns: ['body', 'saved_at'],
      where: 'owner_id = ? AND cache_key = ?',
      whereArgs: [ownerId, key],
    );
    if (rows.isEmpty) return null;
    final entry = CachedJson(
      await _decode(rows.first['body'] as String),
      DateTime.fromMillisecondsSinceEpoch(rows.first['saved_at'] as int),
    );
    _memory.put(memoryKey, entry);
    return entry;
  }

  Future<void> remove(String ownerId, String key) async {
    _memory.remove(_memoryKey(ownerId, key));
    final db = await _db.database;
    await db.delete('cached_responses', where: 'owner_id = ? AND cache_key = ?', whereArgs: [ownerId, key]);
  }

  /// Network falling back to cache: asks the server first and saves every successful answer, so
  /// sold or removed items disappear from the copy too. When the server cannot be reached (no
  /// network, or a 5xx), returns the saved copy instead; without one, the error is rethrown.
  Future<CachedResult<T>> networkFirst<T>({
    required String ownerId,
    required String key,
    required Future<Object?> Function() fetch,
    required T Function(Object? json) parse,
  }) async {
    final Object? json;
    try {
      json = await fetch();
    } on Exception catch (e) {
      if (!_isUnreachable(e)) rethrow;
      final saved = await read(ownerId, key);
      if (saved == null) rethrow;
      return CachedResult.saved(parse(saved.data), saved.savedAt);
    }
    final data = parse(json);
    await save(ownerId, key, json);
    return CachedResult.fresh(data);
  }

  static bool _isUnreachable(Exception e) =>
      e is NetworkException || (e is ApiException && e.statusCode >= 500);

  /// The size is only known after encoding, so long lists are what goes to the isolate.
  static Future<String> _encode(Object? data) => data is List && data.length > isolateListLength
      ? Isolate.run(() => jsonEncode(data))
      : Future.value(jsonEncode(data));

  static Future<Object?> _decode(String text) =>
      text.length > isolateThreshold ? Isolate.run(() => jsonDecode(text)) : Future.value(jsonDecode(text));
}
