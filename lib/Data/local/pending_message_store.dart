import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class PendingMessage {
  final String clientId;
  final String userId;
  final String roomId;
  final String content;
  final DateTime clientCreatedAt;
  final int attempts;
  final String status; // 'PENDING', 'FAILED', 'SENT'
  final String? failureReason;

  PendingMessage({
    required this.clientId,
    required this.userId,
    required this.roomId,
    required this.content,
    required this.clientCreatedAt,
    this.attempts = 0,
    this.status = 'PENDING',
    this.failureReason,
  });

  Map<String, dynamic> toMap() => {
        'client_id': clientId,
        'user_id': userId,
        'room_id': roomId,
        'content': content,
        'client_created_at': clientCreatedAt.toIso8601String(),
        'attempts': attempts,
        'status': status,
        'failure_reason': failureReason,
      };

  factory PendingMessage.fromMap(Map<String, dynamic> map) => PendingMessage(
        clientId: map['client_id'] as String,
        userId: map['user_id'] as String,
        roomId: map['room_id'] as String,
        content: map['content'] as String,
        clientCreatedAt: DateTime.parse(map['client_created_at'] as String),
        attempts: map['attempts'] as int? ?? 0,
        status: map['status'] as String? ?? 'PENDING',
        failureReason: map['failure_reason'] as String?,
      );
}

class PendingMessageStore {
  final AppDatabase appDatabase;

  PendingMessageStore({required this.appDatabase});

  Future<void> insert(PendingMessage message) async {
    final db = await appDatabase.database;
    await db.insert(
      'pending_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingMessage>> getPendingForRoom(String roomId, String userId) async {
    final db = await appDatabase.database;
    final rows = await db.query(
      'pending_messages',
      where: 'room_id = ? AND user_id = ? AND status != ?',
      whereArgs: [roomId, userId, 'SENT'],
      orderBy: 'client_created_at ASC',
    );
    return rows.map(PendingMessage.fromMap).toList();
  }

  Future<List<PendingMessage>> getAllPending(String userId) async {
    final db = await appDatabase.database;
    final rows = await db.query(
      'pending_messages',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'PENDING'],
      orderBy: 'client_created_at ASC',
    );
    return rows.map(PendingMessage.fromMap).toList();
  }

  Future<void> markFailed(String clientId, String reason) async {
    final db = await appDatabase.database;
    await db.rawUpdate('''
      UPDATE pending_messages
      SET attempts = attempts + 1, status = 'FAILED', failure_reason = ?
      WHERE client_id = ?
    ''', [reason, clientId]);
  }

  Future<void> incrementAttempt(String clientId) async {
    final db = await appDatabase.database;
    await db.rawUpdate('''
      UPDATE pending_messages
      SET attempts = attempts + 1
      WHERE client_id = ?
    ''', [clientId]);
  }

  Future<void> delete(String clientId) async {
    final db = await appDatabase.database;
    await db.delete(
      'pending_messages',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  Future<int> countPending(String userId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_messages WHERE user_id = ? AND status != ?',
      [userId, 'SENT'],
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }
}
