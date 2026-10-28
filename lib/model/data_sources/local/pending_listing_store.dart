import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../entities/pending_items.dart';
import 'app_database.dart';
import 'outbox_store.dart';

/// Local store managing unsubmitted listings awaiting network synchronization.
///
/// Implements EC3: Offline listing persistence in SQLite and photo files tracking.
class PendingListingStore {
  final AppDatabase appDatabase;
  final OutboxStore? outboxStore;

  PendingListingStore({required this.appDatabase, this.outboxStore});

  Future<PendingListing> enqueue({
    required String ownerId,
    required Map<String, dynamic> payload,
    List<String> photoPaths = const [],
  }) async {
    if (outboxStore != null) {
      return outboxStore!.enqueueListing(
        ownerId: ownerId,
        payload: payload,
        photoPaths: photoPaths,
      );
    }

    final id = newClientId();
    final listing = PendingListing(
      id: id,
      ownerId: ownerId,
      payload: payload,
      photoPaths: photoPaths,
      createdAt: DateTime.now(),
    );

    final db = await appDatabase.database;
    await db.insert(
      'pending_listings',
      {
        'id': listing.id,
        'owner_id': ownerId,
        'payload': jsonEncode(payload),
        'photo_paths': jsonEncode(photoPaths),
        'created_at': listing.createdAt.millisecondsSinceEpoch,
        'status': PendingStatus.waiting.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return listing;
  }

  Future<List<PendingListing>> getForOwner(String ownerId) async {
    if (outboxStore != null) {
      return outboxStore!.listings(ownerId);
    }
    final db = await appDatabase.database;
    final rows = await db.query(
      'pending_listings',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => PendingListing(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      photoPaths: (jsonDecode(row['photo_paths'] as String) as List).cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      status: PendingStatus.values.where((s) => s.name == row['status']).firstOrNull ?? PendingStatus.waiting,
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
    )).toList();
  }

  Future<List<PendingListing>> getAllForOwner(String ownerId) => getForOwner(ownerId);

  Future<List<PendingListing>> getPendingOnly(String ownerId) async {
    final all = await getForOwner(ownerId);
    return all.where((l) => l.status == PendingStatus.waiting).toList();
  }

  Future<void> delete(String id) async {
    if (outboxStore != null) {
      await outboxStore!.discard(PendingKind.listing, id);
      return;
    }
    final db = await appDatabase.database;
    await db.delete(
      'pending_listings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countPending(String ownerId) async {
    final all = await getForOwner(ownerId);
    return all.where((l) => l.status == PendingStatus.waiting).length;
  }
}
