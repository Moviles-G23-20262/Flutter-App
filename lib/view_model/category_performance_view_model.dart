import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/entities/cached_list.dart';
import '../model/entities/category_performance.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/repositories/connectivity_repository.dart';
import '../model/use_cases/get_category_performance_use_case.dart';

/// The BQ6 card in the Seller Hub: loading, the figures (fresh or the copy saved on the phone),
/// or why they could not load. When [connectivity] reports the network back, a saved copy or an
/// error is replaced by a fresh load.
class CategoryPerformanceViewModel extends ChangeNotifier {
  final GetCategoryPerformanceUseCase getCategoryPerformance;
  StreamSubscription<bool>? _connectivitySubscription;

  CategoryPerformanceViewModel({required this.getCategoryPerformance, ConnectivityRepository? connectivity}) {
    _connectivitySubscription = connectivity?.watch().listen(_onConnectivity, onError: (_) {});
  }

  CachedList<CategoryPerformance>? _report;
  bool _loading = false;
  String? _error;
  bool _disposed = false;
  bool _wasOffline = false;

  /// The last figures loaded; `null` until the first load ends well.
  CachedList<CategoryPerformance>? get report => _report;
  List<CategoryPerformance> get categories => _report?.items ?? const [];
  bool get isLoading => _loading;

  /// The figures on screen are the copy saved on the phone (the server could not be reached).
  bool get isSavedCopy => _report?.isSavedCopy ?? false;
  DateTime? get savedAt => _report?.savedAt;

  /// Set when the last load failed and there is nothing to show.
  String? get error => _error;

  /// The highest listing count, to scale the bars.
  int get highestListings => categories.fold(0, (max, c) => c.totalListings > max ? c.totalListings : max);

  /// Loads the figures once; later calls do nothing unless [force] (the Seller Hub being opened
  /// again, "Try again", the network coming back). What is on screen stays while it loads.
  Future<void> load({bool force = false}) async {
    if (_loading || (_report != null && !force)) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _report = await getCategoryPerformance.execute();
    } on DataException catch (e) {
      if (_report == null) _error = e.message;
    } catch (_) {
      // Never a spinner forever: anything unexpected becomes a message with "Try again".
      if (_report == null) _error = "Couldn't load the category figures. Please try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _onConnectivity(bool online) {
    final reconnected = online && _wasOffline;
    _wasOffline = !online;
    if (online && (reconnected || isSavedCopy || _error != null)) load(force: true);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
