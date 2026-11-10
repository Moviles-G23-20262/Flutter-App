import 'dart:async';

import 'package:flutter/foundation.dart';
import '../model/repositories/connectivity_repository.dart';
import '../model/use_cases/connectivity_use_cases.dart';
import '../model/use_cases/outbox_use_cases.dart';

/// Whether the device is online, which transport it uses (Wi-Fi vs. mobile data), and whether
/// queued outbox items are waiting for Wi-Fi.
class ConnectivityViewModel extends ChangeNotifier {
  final GetConnectivityUseCase getConnectivity;
  final WatchConnectivityUseCase watchConnectivity;
  final GetNetworkTransportUseCase? getTransport;
  final WatchNetworkTransportUseCase? watchTransport;
  final LoadAllowMobileDataUseCase? loadAllowMobileData;
  final SaveAllowMobileDataUseCase? saveAllowMobileData;
  final WatchWaitingForWifiUseCase? watchWaitingForWifi;
  final Future<void> Function()? onAllowMobileDataEnabled;

  ConnectivityViewModel({
    required this.getConnectivity,
    required this.watchConnectivity,
    this.getTransport,
    this.watchTransport,
    this.loadAllowMobileData,
    this.saveAllowMobileData,
    this.watchWaitingForWifi,
    this.onAllowMobileDataEnabled,
  });

  StreamSubscription<bool>? _subscription;
  StreamSubscription<NetworkTransport>? _transportSubscription;
  StreamSubscription<bool>? _waitingForWifiSubscription;

  bool _online = true;
  NetworkTransport _transport = NetworkTransport.wifi;
  bool _allowMobileData = false;
  bool _waitingForWifi = false;
  bool _disposed = false;

  bool get isOnline => _online;
  bool get isOffline => !_online;
  NetworkTransport get transport => _transport;
  bool get isMobileOnly => _transport == NetworkTransport.mobile;
  bool get allowMobileData => _allowMobileData;
  bool get isWaitingForWifi => _waitingForWifi;

  void start() {
    if (_subscription != null) return;
    _subscription = watchConnectivity.execute().listen(_setOnline, onError: (_) {});
    getConnectivity.execute().then(_setOnline, onError: (_) {});

    if (watchTransport != null) {
      _transportSubscription = watchTransport!.execute().listen(_setTransport, onError: (_) {});
    }
    getTransport?.execute().then(_setTransport, onError: (_) {});

    loadAllowMobileData?.execute().then(_setLoadedMobilePref, onError: (_) {});

    final watchWifiWait = watchWaitingForWifi;
    if (watchWifiWait != null) {
      _setWaitingForWifi(watchWifiWait.current);
      _waitingForWifiSubscription = watchWifiWait.execute().listen(_setWaitingForWifi, onError: (_) {});
    }
  }

  /// Toggles the `allow_mobile_data` preference (`SharedPreferences`) and triggers an outbox
  /// flush immediately when turned on.
  Future<void> setAllowMobileData(bool allowed) async {
    if (_disposed) return;
    final changed = _allowMobileData != allowed;
    _allowMobileData = allowed;
    if (allowed) _waitingForWifi = false;
    if (changed) notifyListeners();
    await saveAllowMobileData?.execute(allowed);
    if (allowed && !_disposed) {
      await onAllowMobileDataEnabled?.call();
    }
  }

  void _setOnline(bool online) {
    if (_disposed || online == _online) return;
    _online = online;
    if (!online) _waitingForWifi = false;
    notifyListeners();
  }

  void _setTransport(NetworkTransport kind) {
    if (_disposed || kind == _transport) return;
    _transport = kind;
    if (kind != NetworkTransport.mobile) _waitingForWifi = false;
    notifyListeners();
  }

  void _setLoadedMobilePref(bool allowed) {
    if (_disposed || allowed == _allowMobileData) return;
    _allowMobileData = allowed;
    if (allowed) _waitingForWifi = false;
    notifyListeners();
  }

  void _setWaitingForWifi(bool waiting) {
    if (_disposed || waiting == _waitingForWifi) return;
    _waitingForWifi = waiting;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _transportSubscription?.cancel();
    _waitingForWifiSubscription?.cancel();
    super.dispose();
  }
}
