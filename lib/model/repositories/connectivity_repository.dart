/// How the device reaches the network right now.
enum NetworkTransport { wifi, mobile, none }

abstract class ConnectivityRepository {
  /// Whether the device currently has any network connection.
  Future<bool> isOnline();

  /// Emits `true`/`false` each time the device gains or loses its network connection.
  Stream<bool> watch();
}

/// Optional capability for distinguishing Wi-Fi / unmetered connections from mobile data.
abstract class NetworkTransportRepository {
  /// Current transport kind ([NetworkTransport.wifi], [NetworkTransport.mobile], or [NetworkTransport.none]).
  Future<NetworkTransport> currentTransport();

  /// Emits whenever the active network transport kind changes.
  Stream<NetworkTransport> watchTransport();
}
