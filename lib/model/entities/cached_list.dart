/// A list from the server, or the copy saved on the phone when the server could not be reached.
class CachedList<T> {
  final List<T> items;

  /// When the saved copy was made; `null` when [items] just came from the server.
  final DateTime? savedAt;

  const CachedList(this.items, {this.savedAt});

  bool get isSavedCopy => savedAt != null;
}
