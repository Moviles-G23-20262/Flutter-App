import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../Domain/use_cases/connectivity_use_cases.dart';

/// Whether the device is online. The app keeps working offline with what it already loaded;
/// screens only use this to tell the user and to sync again when the network comes back.
class ConnectivityState extends ChangeNotifier {
  final GetConnectivityUseCase getConnectivity;
  final WatchConnectivityUseCase watchConnectivity;

  ConnectivityState({required this.getConnectivity, required this.watchConnectivity});

  StreamSubscription<bool>? _subscription;
  bool _online = true;
  bool _disposed = false;

  bool get isOnline => _online;
  bool get isOffline => !_online;

  void start() {
    if (_subscription != null) return;
    _subscription = watchConnectivity.execute().listen(_set, onError: (_) {});
    getConnectivity.execute().then(_set, onError: (_) {});
  }

  void _set(bool online) {
    if (_disposed || online == _online) return;
    _online = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
