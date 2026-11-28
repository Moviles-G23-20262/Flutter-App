import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/entities/course_demand.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/repositories/connectivity_repository.dart';
import '../model/use_cases/get_course_demand_use_case.dart';

/// The BQ 19 card in the Seller Hub ("Most wanted courses"): loading, the figures (fresh or the
/// copy saved on the phone) or why they could not load. A saved copy or an error is replaced by a
/// fresh load when the network comes back.
class CourseDemandViewModel extends ChangeNotifier {
  /// Courses shown on the card.
  static const int shown = 5;

  final GetCourseDemandUseCase getCourseDemand;
  StreamSubscription<bool>? _connectivitySubscription;

  CourseDemandViewModel({required this.getCourseDemand, ConnectivityRepository? connectivity}) {
    _connectivitySubscription = connectivity?.watch().listen(_onConnectivity, onError: (_) {});
  }

  CourseDemandReport? _report;
  DateTime? _savedAt;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  CourseDemandReport? get report => _report;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isSavedCopy => _savedAt != null;
  DateTime? get savedAt => _savedAt;

  /// The courses short of listings to show, most wanted first.
  List<CourseDemand> get mostWanted => (_report?.mostWanted ?? const <CourseDemand>[]).take(shown).toList();

  /// Loads once; later calls do nothing unless [force]. What is on screen stays while it loads.
  Future<void> load({bool force = false}) async {
    if (_loading || (_report != null && !force)) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      final result = await getCourseDemand.execute();
      _report = result.report;
      _savedAt = result.savedAt;
    } on DataException catch (e) {
      if (_report == null) _error = e.message;
    } catch (_) {
      if (_report == null) _error = "Couldn't load the most wanted courses. Please try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _onConnectivity(bool online) {
    if (online && (isSavedCopy || _error != null)) load(force: true);
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
