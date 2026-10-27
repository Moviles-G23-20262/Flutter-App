import 'package:connectivity_plus/connectivity_plus.dart';

import '../../Domain/repositories/connectivity_repository.dart';

/// The device's network state through connectivity_plus. Offline means `ConnectivityResult.none`.
class ConnectivityDataSource implements ConnectivityRepository {
  final Connectivity _connectivity;

  ConnectivityDataSource([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _connectivity.checkConnectivity());
    } on Exception {
      // Cannot tell: assume online so the app is never blocked by a failing plugin.
      return true;
    }
  }

  Future<bool> isWifi() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi);
    } catch (_) {
      return false;
    }
  }

  Future<bool> isMobileData() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.mobile);
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> watchResults() =>
      _connectivity.onConnectivityChanged;

  @override
  Stream<bool> watch() => _connectivity.onConnectivityChanged.map(_online).distinct();
}
