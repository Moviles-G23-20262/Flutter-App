import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Data/data_sources/connectivity_data_source.dart';
import '../../Domain/use_cases/connectivity_use_cases.dart';

/// Central connectivity state provider.
///
/// Implements EC13:
/// - Monitors connection status (online vs offline).
/// - Tracks connection medium (Wi-Fi vs mobile data).
/// - Manages the `allow_mobile_data` student preference.
/// - Exposes `isWaitingForWifi` when mobile data is present but sync over cellular is disallowed.
class ConnectivityState extends ChangeNotifier {
  final GetConnectivityUseCase getConnectivity;
  final WatchConnectivityUseCase watchConnectivity;
  final ConnectivityDataSource? dataSource;

  ConnectivityState({
    required this.getConnectivity,
    required this.watchConnectivity,
    this.dataSource,
  });

  StreamSubscription<bool>? _subscription;
  bool _online = true;
  bool _isWifi = false;
  bool _isMobileData = false;
  bool _allowMobileData = false;
  bool _disposed = false;

  bool get isOnline => _online;
  bool get isOffline => !_online;
  bool get isWifi => _isWifi;
  bool get isMobileData => _isMobileData;
  bool get allowMobileData => _allowMobileData;

  /// True when the user is on cellular data and has chosen not to sync heavy requests over mobile.
  bool get isWaitingForWifi => _online && _isMobileData && !_allowMobileData;

  void start() {
    if (_subscription != null) return;
    _loadMobileDataPreference();
    _subscription = watchConnectivity.execute().listen(_setOnline, onError: (_) {});
    getConnectivity.execute().then(_setOnline, onError: (_) {});
    _checkMedium();
  }

  Future<void> _loadMobileDataPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowMobileData = prefs.getBool('allow_mobile_data') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setAllowMobileData(bool allow) async {
    _allowMobileData = allow;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('allow_mobile_data', allow);
    } catch (_) {}
  }

  Future<void> _checkMedium() async {
    if (dataSource != null) {
      _isWifi = await dataSource!.isWifi();
      _isMobileData = await dataSource!.isMobileData();
      notifyListeners();
    }
  }

  void _setOnline(bool online) {
    if (_disposed || online == _online) return;
    _online = online;
    _checkMedium();
    notifyListeners();
  }

  /// Hook invoked by [ApiClient] to report real transport success or failure.
  void reportServerReachability(bool reachable) {
    if (_disposed) return;
    if (_online != reachable) {
      _online = reachable;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
