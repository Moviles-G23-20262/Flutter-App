/// A request for marketplace data failed. [message] is safe to show to the user.
class DataException implements Exception {
  final String message;
  const DataException(this.message);

  @override
  String toString() => 'DataException: $message';
}
