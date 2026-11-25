import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/entities/material_entity.dart';
import '../model/entities/seller_profile_entity.dart';
import '../model/entities/user_summary.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/repositories/connectivity_repository.dart';
import '../model/use_cases/seller_profile_use_cases.dart';

/// State holder for `SellerProfileScreen`.
///
/// Loads a seller's profile via [GetSellerProfileUseCase] (L1 LRU cache → network +
/// background isolate aggregation + L2 SQLite `seller_profiles` fallback), supports
/// pull-to-refresh (`forceRefresh: true`), and automatically reloads when connectivity
/// returns after an offline view or offline failure.
class SellerProfileViewModel extends ChangeNotifier {
  final UserSummary initialSeller;
  final GetSellerProfileUseCase getSellerProfile;
  final ConnectivityRepository? connectivity;
  final List<MaterialEntity> Function()? knownMaterials;

  StreamSubscription<bool>? _connectivitySub;
  bool _wasOffline = false;
  bool _disposed = false;
  int _generation = 0;

  SellerProfileData? _profile;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  bool _isOfflineError = false;

  SellerProfileViewModel({
    required this.initialSeller,
    required this.getSellerProfile,
    this.connectivity,
    this.knownMaterials,
  }) {
    final repo = connectivity;
    if (repo != null) {
      _connectivitySub = repo.watch().listen(_onConnectivityChanged, onError: (_) {});
    }
  }

  UserSummary get seller => _profile?.seller ?? initialSeller;
  SellerProfileData? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  bool get isOfflineError => _isOfflineError;
  DateTime? get savedAt => _profile?.savedAt;
  bool get isShowingOfflineCopy => _profile?.isOfflineCopy ?? false;

  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_generation;
    if (_profile == null) {
      _isLoading = true;
    } else if (forceRefresh) {
      _isRefreshing = true;
    }
    _error = null;
    _isOfflineError = false;
    _notify();

    try {
      final result = await getSellerProfile.execute(
        initialSeller,
        knownMaterials: knownMaterials?.call(),
        forceRefresh: forceRefresh,
      );
      if (_disposed || generation != _generation) return;
      _profile = result;
      _error = null;
      _isOfflineError = false;
    } on NoConnectionException catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e.message;
      _isOfflineError = true;
    } on DataException catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e.message;
      _isOfflineError = false;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _error = 'Could not load seller profile. Please try again.';
      _isOfflineError = false;
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        _isRefreshing = false;
        _notify();
      }
    }
  }

  /// Pull-to-refresh entry point: bypasses the L1 memory cache and fetches fresh data.
  Future<void> refresh() => load(forceRefresh: true);

  void _onConnectivityChanged(bool isOnline) {
    final reconnected = isOnline && _wasOffline;
    _wasOffline = !isOnline;
    if (reconnected && (isShowingOfflineCopy || _isOfflineError || _profile == null)) {
      load(forceRefresh: true);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    super.dispose();
  }
}
