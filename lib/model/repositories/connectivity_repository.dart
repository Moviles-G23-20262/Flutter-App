abstract class ConnectivityRepository {
  /// Whether the device currently has any network connection.
  Future<bool> isOnline();

  /// Emits `true`/`false` each time the device gains or loses its network connection.
  Stream<bool> watch();
}
