import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// A seller profile JSON snapshot previously persisted in SQLite (`seller_profiles`).
class StoredSellerProfile {
  final Map<String, dynamic> body;
  final DateTime savedAt;

  const StoredSellerProfile({required this.body, required this.savedAt});
}

/// Dedicated local SQLite store for visited seller profiles (`seller_profiles` table, DB v4).
///
/// Keeps at most [maxCachedSellers] (30) most recently viewed sellers; older entries are
/// pruned inside the same SQLite transaction as each upsert so storage stays bounded.
class SellerProfileStore {
  static const String table = 'seller_profiles';
  static const int maxCachedSellers = 30;

  final AppDatabase _db;
  final DateTime Function() _clock;

  SellerProfileStore(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Upserts [sellerId]'s JSON [body] and prunes rows beyond the [maxCachedSellers] newest
  /// inside a single atomic transaction.
  Future<DateTime> save(String sellerId, Map<String, dynamic> body, {DateTime? now}) async {
    final db = await _db.database;
    final savedAt = (now ?? _clock()).toUtc();
    final encoded = jsonEncode(body);
    await db.transaction((txn) async {
      await txn.insert(
        table,
        {
          'seller_id': sellerId,
          'body': encoded,
          'saved_at': savedAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.rawDelete(
        '''
        DELETE FROM $table
        WHERE seller_id NOT IN (
          SELECT seller_id FROM $table
          ORDER BY saved_at DESC
          LIMIT ?
        )
        ''',
        [maxCachedSellers],
      );
    });
    return savedAt;
  }

  /// Reads the saved profile snapshot for [sellerId], or `null` if never visited or corrupted.
  Future<StoredSellerProfile?> read(String sellerId) async {
    final db = await _db.database;
    final rows = await db.query(
      table,
      columns: ['body', 'saved_at'],
      where: 'seller_id = ?',
      whereArgs: [sellerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['body'] as String);
      if (decoded is! Map<String, dynamic>) return null;
      return StoredSellerProfile(
        body: decoded,
        savedAt: DateTime.fromMillisecondsSinceEpoch(rows.first['saved_at'] as int, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the current number of cached seller profile rows.
  Future<int> count() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (result.first['c'] as int?) ?? 0;
  }

  /// Clears all cached seller profiles.
  Future<void> clear() async {
    final db = await _db.database;
    await db.delete(table);
  }
}
