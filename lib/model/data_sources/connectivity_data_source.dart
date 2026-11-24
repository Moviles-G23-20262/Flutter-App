import 'package:connectivity_plus/connectivity_plus.dart';

import '../repositories/connectivity_repository.dart';

/// The device's network state through connectivity_plus.
///
/// Only IP-capable transports (Wi-Fi, Ethernet, Mobile, VPN) count as online: on real Android/iOS
/// phones, Bluetooth (`ConnectivityResult.bluetooth`) stays active in Airplane Mode (e.g. earbuds
/// or smartwatches) and must NOT trick the app into thinking it has internet.
class ConnectivityDataSource implements ConnectivityRepository, NetworkTransportRepository {
  final Connectivity _connectivity;

  ConnectivityDataSource([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  static bool _isInternetTransport(ConnectivityResult r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.vpn;

  static bool isOnlineResults(List<ConnectivityResult> results) =>
      results.any(_isInternetTransport);

  static NetworkTransport transportFromResults(List<ConnectivityResult> results) {
    //optional mobile data - Waiting for Wi-Fi - Sabrina 
    if (results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn)) {
      return NetworkTransport.wifi;
    }
    if (results.any((r) => r == ConnectivityResult.mobile)) {
      return NetworkTransport.mobile;
    }
    return NetworkTransport.none;
  }

  @override
  Future<bool> isOnline() async {
    try {
      return isOnlineResults(await _connectivity.checkConnectivity());
    } on Exception {
      // Cannot tell: assume online so the app is never blocked by a failing plugin.
      return true;
    }
  }

  @override
  Stream<bool> watch() => _connectivity.onConnectivityChanged.map(isOnlineResults).distinct();

  @override
  Future<NetworkTransport> currentTransport() async {
    try {
      return transportFromResults(await _connectivity.checkConnectivity());
    } on Exception {
      // Cannot tell: assume unmetered so background sync is never silently wedged.
      return NetworkTransport.wifi;
    }
  }

  @override
  Stream<NetworkTransport> watchTransport() =>
      _connectivity.onConnectivityChanged.map(transportFromResults).distinct();
}
