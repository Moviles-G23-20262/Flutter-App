import 'package:flutter/foundation.dart';

import '../model/use_cases/recent_searches_use_cases.dart';

/// The recent searches shown under the search box. They come from the phone (Hive), so they are
/// there without a connection. The View only renders [searches] and forwards taps.
class RecentSearchesViewModel extends ChangeNotifier {
  final GetRecentSearchesUseCase getRecent;
  final SaveRecentSearchUseCase saveRecent;
  final RemoveRecentSearchUseCase removeRecent;
  final ClearRecentSearchesUseCase clearRecent;

  RecentSearchesViewModel({
    required this.getRecent,
    required this.saveRecent,
    required this.removeRecent,
    required this.clearRecent,
  });

  String? _ownerId;
  List<String> _searches = const [];
  int _generation = 0; // lets a read that finishes after the user changed be ignored
  bool _disposed = false;

  /// The saved searches of the current user, most recent first.
  List<String> get searches => _searches;

  /// Switches to [ownerId]'s searches (null when nobody is signed in: there are none to show).
  Future<void> load(String? ownerId) async {
    final generation = ++_generation;
    if (ownerId != _ownerId) {
      _ownerId = ownerId;
      _searches = const [];
      _notify();
    }
    if (ownerId == null) return;
    final loaded = await getRecent.execute(ownerId);
    if (generation != _generation) return;
    _searches = loaded;
    _notify();
  }

  /// Remembers [query] as the latest search. Nothing happens without a signed-in user.
  Future<void> record(String query) => _update((id) => saveRecent.execute(id, query));

  Future<void> forget(String query) => _update((id) => removeRecent.execute(id, query));

  Future<void> clearAll() async {
    final id = _ownerId;
    if (id == null) return;
    _generation++;
    _searches = const [];
    _notify();
    await clearRecent.execute(id);
  }

  Future<void> _update(Future<List<String>> Function(String ownerId) change) async {
    final id = _ownerId;
    if (id == null) return;
    final generation = ++_generation;
    final updated = await change(id);
    if (generation != _generation || id != _ownerId) return;
    _searches = updated;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
