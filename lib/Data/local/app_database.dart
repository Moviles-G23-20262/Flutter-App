import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Manages the local SQLite database for offline caching, outbox messages, and pending listings.
///
/// Kept strictly on the phone private storage. No remote database connection is required for this layer.
class AppDatabase {
  static const String databaseName = 'campus_swap_local.db';
  static const int databaseVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    // 1. Cached responses from the server (feed, inbox, search)
    await db.execute('''
      CREATE TABLE cached_responses (
        cache_key TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        response_json TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_cached_user_endpoint ON cached_responses(user_id, endpoint)');

    // 2. Pending chat messages waiting in outbox
    await db.execute('''
      CREATE TABLE pending_messages (
        client_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        room_id TEXT NOT NULL,
        content TEXT NOT NULL,
        client_created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',
        failure_reason TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_pending_messages_user_room ON pending_messages(user_id, room_id)');

    // 3. Pending listings waiting to be published
    await db.execute('''
      CREATE TABLE pending_listings (
        client_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        course_code TEXT,
        price REAL NOT NULL,
        condition TEXT,
        category TEXT NOT NULL,
        photo_paths TEXT NOT NULL,
        uploaded_urls TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',
        failure_reason TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_pending_listings_owner ON pending_listings(owner_id)');

    // 4. Pending actions (check-ins, ratings, proposals)
    await db.execute('''
      CREATE TABLE pending_actions (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        exchange_id TEXT,
        payload_json TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',
        failure_reason TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Explicit upgrade hooks for future migrations
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
