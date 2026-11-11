import 'package:hive_ce/hive_ce.dart';

/// The recent searches of each user, kept in a Hive box (a key/value database on the phone):
/// the key is the user id and the value the list of queries, most recent first.
///
/// Hive suits this: a few short strings per user, read and written as a whole, with no need
/// for queries or a schema. They stay after the app is closed and need no connection.
///
/// Call `Hive.initFlutter()` once at startup (see `main`) before using it.
class RecentSearchesStore {
  static const String boxName = 'recent_searches';

  final Future<Box<dynamic>> Function() _openBox;
  Future<Box<dynamic>>? _box;

  /// [openBox] is replaceable so tests can open a box in a temporary folder.
  RecentSearchesStore({Future<Box<dynamic>> Function()? openBox})
      : _openBox = openBox ?? (() => Hive.openBox<dynamic>(boxName));

  Future<Box<dynamic>> get _opened => _box ??= _openBox();

  /// The queries saved for [ownerId], most recent first; empty when there are none.
  Future<List<String>> read(String ownerId) async {
    final raw = (await _opened).get(ownerId);
    if (raw is! List) return const [];
    return [for (final item in raw) if (item is String) item];
  }

  /// Replaces what is saved for [ownerId]. An empty list removes the key.
  Future<void> write(String ownerId, List<String> queries) async {
    final box = await _opened;
    if (queries.isEmpty) {
      await box.delete(ownerId);
    } else {
      await box.put(ownerId, List<String>.of(queries));
    }
  }
}
