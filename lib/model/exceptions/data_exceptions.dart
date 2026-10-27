/// A request for marketplace data failed. [message] is safe to show to the user.
class DataException implements Exception {
  final String message;
  const DataException(this.message);

  @override
  String toString() => 'DataException: $message';
}

/// The request never reached the server (no network, timeout). What the user did can be saved
/// on the phone and sent later.
class NoConnectionException extends DataException {
  const NoConnectionException()
      : super("Can't reach the server. Check your connection and try again.");
}
