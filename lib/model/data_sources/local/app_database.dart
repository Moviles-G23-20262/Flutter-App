import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's local SQLite database (sqflite).
///
/// - `cached_responses`: the last server answer per user and screen, for offline reading.
/// - `pending_messages`, `pending_listings`, `pending_actions`: the outbox. Actions saved on the
///   phone first and sent to the server later by the sync service.
///
/// Every row stores its `owner_id`, so two accounts on the same phone never see or send each
/// other's data.
class AppDatabase {
  static const String fileName = 'campus_swap.db';

  /// Raise it and add a step to [_upgrade] whenever the schema changes.
  ///
  /// 1: cached_responses, pending_messages, pending_listings.
  /// 2: pending_actions (exchange completion, rating, meeting proposal).
  static const int version = 2;

  final Future<Database> Function() _open;
  Future<Database>? _database;

  AppDatabase._(this._open);

  /// The database file in the app's private databases folder.
  factory AppDatabase() => AppDatabase._(() async {
        final path = p.join(await getDatabasesPath(), fileName);
        return openDatabase(path, version: version, onCreate: _create, onUpgrade: _upgrade);
      });

  /// A database opened with [factory] at [path], e.g. sqflite_common_ffi's in-memory one in tests.
  /// Not shared, so every in-memory database starts empty.
  factory AppDatabase.withFactory(DatabaseFactory factory, {String path = inMemoryDatabasePath}) =>
      AppDatabase._(() => factory.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: version,
              onCreate: _create,
              onUpgrade: _upgrade,
              singleInstance: false,
            ),
          ));

  /// Opened on first use and then shared.
  Future<Database> get database => _database ??= _open();

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await (await database).close();
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE cached_responses (
          owner_id TEXT NOT NULL,
          cache_key TEXT NOT NULL,
          body TEXT NOT NULL,
          saved_at INTEGER NOT NULL,
          PRIMARY KEY (owner_id, cache_key)
        )''')
      ..execute('''
        CREATE TABLE pending_messages (
          id TEXT PRIMARY KEY,
          owner_id TEXT NOT NULL,
          chat_room_id TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )''')
      ..execute('''
        CREATE TABLE pending_listings (
          id TEXT PRIMARY KEY,
          owner_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          photo_paths TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )''')
      ..execute('CREATE INDEX idx_pending_messages_owner ON pending_messages (owner_id, created_at)')
      ..execute('CREATE INDEX idx_pending_listings_owner ON pending_listings (owner_id, created_at)');
    _createPendingActions(batch);
    await batch.commit(noResult: true);
  }

  static void _createPendingActions(Batch batch) => batch
    ..execute('''
      CREATE TABLE pending_actions (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        group_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )''')
    ..execute('CREATE INDEX idx_pending_actions_owner ON pending_actions (owner_id, created_at)');

  /// Runs every step between the installed schema and [version], in order, so a phone that skips
  /// an app update still ends up with the newest schema. Queued rows and saved copies are kept.
  static Future<void> _upgrade(Database db, int from, int to) async {
    final batch = db.batch();
    if (from < 2) _createPendingActions(batch);
    await batch.commit(noResult: true);
  }
}
