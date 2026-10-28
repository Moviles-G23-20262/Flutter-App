import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../entities/pending_items.dart';
import 'app_database.dart';

/// The outbox: `pending_messages`, `pending_listings` and `pending_actions`. The user's action is written here
/// first and shown at once; [OutboxSyncService] sends it later.
///
/// Rows belong to one user, and every query filters by owner.
class OutboxStore {
  final AppDatabase _db;
  final DateTime Function() _now;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  OutboxStore(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Fires after every write, so screens can show "waiting" / "sent" without polling.
  Stream<void> get changes => _changes.stream;

  Stream<int> get pendingCountStream async* {
    yield await pendingCount();
    await for (final _ in _changes.stream) {
      yield await pendingCount();
    }
  }

  Future<int> pendingCount([String? ownerId]) async {
    final db = await _db.database;
    final where = ownerId != null ? ' WHERE owner_id = ?' : '';
    final args = ownerId != null ? [ownerId] : null;
    final m = (await db.rawQuery('SELECT COUNT(*) as c FROM pending_messages$where', args)).first['c'] as int? ?? 0;
    final l = (await db.rawQuery('SELECT COUNT(*) as c FROM pending_listings$where', args)).first['c'] as int? ?? 0;
    final a = (await db.rawQuery('SELECT COUNT(*) as c FROM pending_actions$where', args)).first['c'] as int? ?? 0;
    return m + l + a;
  }

  // Messages

  Future<PendingMessage> enqueueMessage({
    required String ownerId,
    required String chatRoomId,
    required String content,
  }) async {
    final message = PendingMessage(
      id: newClientId(),
      ownerId: ownerId,
      chatRoomId: chatRoomId,
      content: content,
      createdAt: _now(),
    );
    final db = await _db.database;
    await db.insert('pending_messages', {
      'id': message.id,
      'owner_id': ownerId,
      'chat_room_id': chatRoomId,
      'content': content,
      'created_at': message.createdAt.millisecondsSinceEpoch,
      'status': PendingStatus.waiting.name,
    });
    _changed();
    return message;
  }

  /// [ownerId]'s queued messages, oldest first; only those of [chatRoomId] when given.
  Future<List<PendingMessage>> messages(String ownerId, {String? chatRoomId}) async {
    final db = await _db.database;
    final rows = await db.query(
      'pending_messages',
      where: chatRoomId == null ? 'owner_id = ?' : 'owner_id = ? AND chat_room_id = ?',
      whereArgs: [ownerId, ?chatRoomId],
      orderBy: 'created_at, rowid',
    );
    return rows.map(_messageFromRow).toList();
  }

  // Listings

  Future<PendingListing> enqueueListing({
    required String ownerId,
    required Map<String, dynamic> payload,
    List<String> photoPaths = const [],
  }) async {
    final listing = PendingListing(
      id: newClientId(),
      ownerId: ownerId,
      payload: payload,
      photoPaths: photoPaths,
      createdAt: _now(),
    );
    final db = await _db.database;
    await db.insert('pending_listings', {
      'id': listing.id,
      'owner_id': ownerId,
      'payload': jsonEncode(payload),
      'photo_paths': jsonEncode(photoPaths),
      'created_at': listing.createdAt.millisecondsSinceEpoch,
      'status': PendingStatus.waiting.name,
    });
    _changed();
    return listing;
  }

  Future<List<PendingListing>> listings(String ownerId) async {
    final db = await _db.database;
    final rows = await db.query(
      'pending_listings',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at, rowid',
    );
    return rows.map(_listingFromRow).toList();
  }

  /// Alias for [listings].
  Future<List<PendingListing>> pendingListings(String ownerId) => listings(ownerId);

  /// Discards a queued listing.
  Future<void> deleteListing(String id) => discard(PendingKind.listing, id);

  // Exchange steps (completion, rating, meeting proposal)

  Future<PendingAction> enqueueAction({
    required String ownerId,
    required PendingActionKind kind,
    required String groupId,
    required Map<String, dynamic> payload,
  }) async {
    final action = PendingAction(
      id: newClientId(),
      ownerId: ownerId,
      kind: kind,
      groupId: groupId,
      payload: payload,
      createdAt: _now(),
    );
    final db = await _db.database;
    await db.insert('pending_actions', {
      'id': action.id,
      'owner_id': ownerId,
      'kind': kind.name,
      'group_id': groupId,
      'payload': jsonEncode(payload),
      'created_at': action.createdAt.millisecondsSinceEpoch,
      'status': PendingStatus.waiting.name,
    });
    _changed();
    return action;
  }

  /// [ownerId]'s queued exchange steps, oldest first.
  Future<List<PendingAction>> actions(String ownerId) async {
    final db = await _db.database;
    final rows = await db.query(
      'pending_actions',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at, rowid',
    );
    return rows.map(_actionFromRow).nonNulls.toList();
  }

  // Outcomes, used by the sync service

  /// The server confirmed it: the row is no longer needed.
  Future<void> markSent(PendingKind kind, String id) => _delete(kind, id);

  /// Not delivered (no network, 5xx, expired session): it stays waiting, one attempt more.
  Future<void> markRetry(PendingKind kind, String id, String reason) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE ${kind.table} SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [reason, id],
    );
    _changed();
  }

  /// The server refused it (4xx). It is kept, with the reason, until the user discards it.
  Future<void> markRefused(PendingKind kind, String id, String reason) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE ${kind.table} SET attempts = attempts + 1, status = ?, last_error = ? WHERE id = ?',
      [PendingStatus.refused.name, reason, id],
    );
    _changed();
  }

  /// The user gave up on a queued item.
  Future<void> discard(PendingKind kind, String id) => _delete(kind, id);

  Future<void> _delete(PendingKind kind, String id) async {
    final db = await _db.database;
    await db.delete(kind.table, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  static PendingStatus _status(Object? name) =>
      PendingStatus.values.where((s) => s.name == name).firstOrNull ?? PendingStatus.waiting;

  static PendingMessage _messageFromRow(Map<String, Object?> row) => PendingMessage(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        chatRoomId: row['chat_room_id'] as String,
        content: row['content'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        status: _status(row['status']),
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
      );

  /// `null` for a kind this app version does not know (written by a newer one).
  static PendingAction? _actionFromRow(Map<String, Object?> row) {
    final kind = PendingActionKind.values.where((k) => k.name == row['kind']).firstOrNull;
    if (kind == null) return null;
    return PendingAction(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      kind: kind,
      groupId: row['group_id'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      status: _status(row['status']),
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String?,
    );
  }

  static PendingListing _listingFromRow(Map<String, Object?> row) => PendingListing(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        photoPaths: (jsonDecode(row['photo_paths'] as String) as List).cast<String>(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        status: _status(row['status']),
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
      );
}

/// Which outbox table an item lives in.
enum PendingKind {
  message('pending_messages'),
  listing('pending_listings'),
  action('pending_actions');

  final String table;
  const PendingKind(this.table);
}

final Random _random = Random.secure();

/// A random (version 4) UUID, used as the client id of every queued item.
String newClientId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
