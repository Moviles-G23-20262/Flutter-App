import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class PendingListing {
  final String clientId;
  final String ownerId;
  final String title;
  final String description;
  final String? courseCode;
  final double price;
  final String? condition;
  final String category;
  final List<String> photoPaths;
  final List<String> uploadedUrls;
  final int attempts;
  final String status; // 'PENDING', 'FAILED', 'SENT'
  final String? failureReason;
  final DateTime createdAt;

  PendingListing({
    required this.clientId,
    required this.ownerId,
    required this.title,
    required this.description,
    this.courseCode,
    required this.price,
    this.condition,
    required this.category,
    required this.photoPaths,
    this.uploadedUrls = const [],
    this.attempts = 0,
    this.status = 'PENDING',
    this.failureReason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'client_id': clientId,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'course_code': courseCode,
        'price': price,
        'condition': condition,
        'category': category,
        'photo_paths': jsonEncode(photoPaths),
        'uploaded_urls': jsonEncode(uploadedUrls),
        'attempts': attempts,
        'status': status,
        'failure_reason': failureReason,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory PendingListing.fromMap(Map<String, dynamic> map) => PendingListing(
        clientId: map['client_id'] as String,
        ownerId: map['owner_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        courseCode: map['course_code'] as String?,
        price: (map['price'] as num).toDouble(),
        condition: map['condition'] as String?,
        category: map['category'] as String,
        photoPaths: List<String>.from(jsonDecode(map['photo_paths'] as String) as List),
        uploadedUrls: map['uploaded_urls'] != null
            ? List<String>.from(jsonDecode(map['uploaded_urls'] as String) as List)
            : const [],
        attempts: map['attempts'] as int? ?? 0,
        status: map['status'] as String? ?? 'PENDING',
        failureReason: map['failure_reason'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

class PendingListingStore {
  final AppDatabase appDatabase;

  PendingListingStore({required this.appDatabase});

  Future<void> insert(PendingListing listing) async {
    final db = await appDatabase.database;
    await db.insert(
      'pending_listings',
      listing.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingListing>> getAllForOwner(String ownerId) async {
    final db = await appDatabase.database;
    final rows = await db.query(
      'pending_listings',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(PendingListing.fromMap).toList();
  }

  Future<List<PendingListing>> getPendingOnly(String ownerId) async {
    final db = await appDatabase.database;
    final rows = await db.query(
      'pending_listings',
      where: 'owner_id = ? AND status = ?',
      whereArgs: [ownerId, 'PENDING'],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingListing.fromMap).toList();
  }

  Future<void> markFailed(String clientId, String reason) async {
    final db = await appDatabase.database;
    await db.rawUpdate('''
      UPDATE pending_listings
      SET attempts = attempts + 1, status = 'FAILED', failure_reason = ?
      WHERE client_id = ?
    ''', [reason, clientId]);
  }

  Future<void> updateUploadedUrls(String clientId, List<String> urls) async {
    final db = await appDatabase.database;
    await db.update(
      'pending_listings',
      {'uploaded_urls': jsonEncode(urls)},
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  Future<void> delete(String clientId) async {
    final db = await appDatabase.database;
    await db.delete(
      'pending_listings',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  Future<int> countPending(String ownerId) async {
    final db = await appDatabase.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_listings WHERE owner_id = ? AND status != ?',
      [ownerId, 'SENT'],
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }
}
