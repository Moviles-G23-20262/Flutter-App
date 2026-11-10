import 'package:connectivity_plus/connectivity_plus.dart';

import '../repositories/connectivity_repository.dart';

/// The device's network state through connectivity_plus. Offline means `ConnectivityResult.none`.
class ConnectivityDataSource implements ConnectivityRepository, NetworkTransportRepository {
  final Connectivity _connectivity;

  ConnectivityDataSource([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  static NetworkTransport _transport(List<ConnectivityResult> results) {
    if (results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet)) {
      return NetworkTransport.wifi;
    }
    if (results.any((r) => r == ConnectivityResult.mobile)) {
      return NetworkTransport.mobile;
    }
    if (results.any((r) => r != ConnectivityResult.none)) {
      return NetworkTransport.wifi;
    }
    return NetworkTransport.none;
  }

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _connectivity.checkConnectivity());
    } on Exception {
      // Cannot tell: assume online so the app is never blocked by a failing plugin.
      return true;
    }
  }

  @override
  Stream<bool> watch() => _connectivity.onConnectivityChanged.map(_online).distinct();

  @override
  Future<NetworkTransport> currentTransport() async {
    try {
      return _transport(await _connectivity.checkConnectivity());
    } on Exception {
      // Cannot tell: assume unmetered so background sync is never silently wedged.
      return NetworkTransport.wifi;
    }
  }

  @override
  Stream<NetworkTransport> watchTransport() =>
      _connectivity.onConnectivityChanged.map(_transport).distinct();
}
