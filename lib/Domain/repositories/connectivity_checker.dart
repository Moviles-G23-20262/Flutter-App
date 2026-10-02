/// Tells whether the device currently has a network connection.
abstract class ConnectivityChecker {
  Future<bool> get isOnline;
}
