import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/isolates/listing_health_analyzer.dart';
import '../model/entities/dead_listings_insight.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/pending_items.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/rules/client_id.dart';
import '../model/repositories/listing_health_preferences_repository.dart';
import '../model/use_cases/listing_health_use_cases.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/pending_action_use_cases.dart';

/// MVVM ViewModel for [ListingHealthScreen] (BQ 10 Dead Listings & Price-Drop Advisor).
///
/// Orchestrates:
/// - BQ 10 network-first reads with SQLite/LRU [ResponseCache] fallback ([getInsight])
/// - Per-seller preferences persisted in SharedPreferences ([staleDays], [dismissedIds])
/// - Off-main-thread risk analysis and interactive What-If simulation via [Isolate.run]
/// - Online `PATCH /materials/:id` price updates + offline SQLite outbox queueing ([queuePriceUpdate])
class ListingHealthViewModel extends ChangeNotifier {
  final String userId;
  final GetDeadListingsInsightUseCase getInsight;
  final LoadListingHealthPreferencesUseCase loadPreferences;
  final SaveListingHealthStaleDaysUseCase saveStaleDays;
  final SaveDismissedHealthAlertsUseCase saveDismissedIds;
  final UpdateListingPriceUseCase updateListingPrice;
  final QueuePriceUpdateUseCase queuePriceUpdate;
  final WatchPendingActionsUseCase? watchPendingActions;
  final DiscardPendingActionUseCase? discardPendingAction;
  final List<MaterialEntity> Function() getMarketplaceListings;
  final void Function(MaterialEntity updated)? onMaterialUpdated;
  final double? Function(String category)? baselineSellDays;

  ListingHealthViewModel({
    required this.userId,
    required this.getInsight,
    required this.loadPreferences,
    required this.saveStaleDays,
    required this.saveDismissedIds,
    required this.updateListingPrice,
    required this.queuePriceUpdate,
    this.watchPendingActions,
    this.discardPendingAction,
    required this.getMarketplaceListings,
    this.onMaterialUpdated,
    this.baselineSellDays,
  });

  DeadListingsInsight _insight = DeadListingsInsight.empty;
  ListingHealthAnalysisResult _analysis = ListingHealthAnalysisResult.empty;
  DateTime? _savedAt;
  int _staleDays = ListingHealthPreferencesRepository.defaultStaleDays;
  Set<String> _dismissedIds = {};
  bool _showDismissed = false;
  bool _loading = false;
  bool _loadedOnce = false;
  bool _analyzing = false;
  String? _error;
  String? _statusMessage;

  final Set<String> _updatingIds = {};
  final Map<String, double> _localPriceOverrides = {};
  Map<String, PendingAction> _pendingPriceActions = const {};
  StreamSubscription<List<PendingAction>>? _pendingSub;

  String? _simulatingListingId;
  double _simulatedPrice = 0;
  PriceDropSimulation? _simulation;
  bool _simulating = false;
  int _loadGeneration = 0;
  int _analyzeGeneration = 0;
  int _simGeneration = 0;
  bool _disposed = false;

  DeadListingsInsight get insight => _insight;
  DeadListingSummary get summary => _insight.summary;
  List<DeadSurvivalPoint> get survivalCurve => _insight.survivalCurve;
  List<DeadListingCluster> get clusters => _insight.clusters;
  SellerHealthOverview? get sellerSummary => _insight.sellerSummary;

  List<SellerListingHealthItem> get activeAdvisories => _analysis.activeAdvisories;
  List<SellerListingHealthItem> get dismissedAdvisories => _analysis.dismissedAdvisories;
  List<SellerListingHealthItem> get visibleAdvisories =>
      _showDismissed ? [..._analysis.activeAdvisories, ..._analysis.dismissedAdvisories] : _analysis.activeAdvisories;
  bool get usedLocalFallback => _analysis.usedLocalFallback;
  int get lastAnalysisMicroseconds => _analysis.elapsedMicroseconds;

  DateTime? get savedAt => _savedAt;
  bool get isShowingCached => _savedAt != null;
  int get staleDays => _staleDays;
  bool get showDismissed => _showDismissed;
  bool get isLoading => _loading;
  bool get isFirstLoad => !_loadedOnce;
  bool get isAnalyzing => _analyzing;
  String? get error => _error;
  String? get statusMessage => _statusMessage;

  String? get simulatingListingId => _simulatingListingId;
  double get simulatedPrice => _simulatedPrice;
  PriceDropSimulation? get simulation => _simulation;
  bool get isSimulating => _simulating;

  bool isDismissed(String listingId) => _dismissedIds.contains(listingId);
  bool isUpdating(String listingId) => _updatingIds.contains(listingId);
  PendingAction? pendingActionFor(String listingId) => _pendingPriceActions[listingId];
  bool isPriceQueued(String listingId) => _pendingPriceActions.containsKey(listingId);

  Future<void> initialize() async {
    _listenPendingActions();
    if (userId.isNotEmpty) {
      final prefs = await loadPreferences.execute(userId);
      if (_disposed) return;
      _staleDays = prefs.staleDays;
      _dismissedIds = Set<String>.of(prefs.dismissedIds);
    }
    await load();
  }

  void _listenPendingActions() {
    final watch = watchPendingActions;
    if (watch == null || userId.isEmpty) return;
    _pendingSub?.cancel();
    _pendingSub = watch.execute(userId).listen((actions) {
      if (_disposed) return;
      final next = <String, PendingAction>{};
      for (final action in actions) {
        if (action.kind != PendingActionKind.updateListingPrice) continue;
        final matId = action.payload['materialId']?.toString() ?? action.groupId;
        // Keep the newest queued edit for that listing so UI matches its final target price.
        next[matId] = action;
        final rawPrice = action.payload['price'];
        final parsed = rawPrice is num ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '');
        if (parsed != null && parsed > 0) {
          _localPriceOverrides[matId] = parsed;
        }
      }
      final finishedIds = _pendingPriceActions.keys.where((id) => !next.containsKey(id)).toList();
      _pendingPriceActions = Map.unmodifiable(next);
      _notify();
      if (finishedIds.isNotEmpty && _loadedOnce) {
        for (final id in finishedIds) {
          _localPriceOverrides.remove(id);
        }
        load(force: true);
      } else if (_loadedOnce) {
        _reanalyzeInIsolate();
      }
    }, onError: (_) {});
  }

  Future<void> load({bool force = false}) async {
    if (_loading && !force) return;
    final gen = ++_loadGeneration;
    _loading = true;
    _error = null;
    _notify();

    try {
      final result = await getInsight.execute(
        staleDays: _staleDays,
        sellerId: isUuid(userId) ? userId : null,
      );
      if (_disposed || gen != _loadGeneration) return;
      _insight = result.data;
      _savedAt = result.savedAt;
      await _reanalyzeInIsolate();
    } on DataException catch (e) {
      if (_disposed || gen != _loadGeneration) return;
      // Still analyze locally cached seller listings in a background isolate if BQ 10 is offline
      // and has never been cached yet.
      await _reanalyzeInIsolate();
      if (_disposed || gen != _loadGeneration) return;
      if (!_insight.hasData && _analysis.activeAdvisories.isEmpty && _analysis.dismissedAdvisories.isEmpty) {
        _error = e.message;
      } else {
        _statusMessage ??= e.message;
      }
    } catch (_) {
      if (_disposed || gen != _loadGeneration) return;
      await _reanalyzeInIsolate();
      if (_disposed || gen != _loadGeneration) return;
      if (!_insight.hasData && _analysis.activeAdvisories.isEmpty) {
        _error = 'Could not load listing health analysis right now.';
      }
    } finally {
      if (!_disposed && gen == _loadGeneration) {
        _loading = false;
        _loadedOnce = true;
        _notify();
      }
    }
  }

  Future<void> _reanalyzeInIsolate() async {
    final gen = ++_analyzeGeneration;
    _analyzing = true;
    _notify();
    final all = getMarketplaceListings();
    final sellerOwned = all.where((m) => m.sellerId == userId).toList(growable: false);
    final analyzed = await analyzeSellerListingHealth(
      report: _insight,
      sellerListings: sellerOwned,
      allMarketplaceListings: all,
      sellerId: userId,
      staleDays: _staleDays,
      dismissedIds: _dismissedIds,
      localPriceOverrides: _localPriceOverrides,
    );
    if (_disposed || gen != _analyzeGeneration) return;
    _analysis = analyzed;
    _analyzing = false;
    _notify();
  }

  Future<void> changeStaleDays(int days) async {
    if (!ListingHealthPreferencesRepository.allowedStaleDays.contains(days) || days == _staleDays) {
      return;
    }
    _staleDays = days;
    _statusMessage = null;
    _notify();
    if (userId.isNotEmpty) {
      await saveStaleDays.execute(userId, days);
    }
    await load(force: true);
  }

  Future<void> toggleDismissAlert(String listingId) async {
    final next = Set<String>.of(_dismissedIds);
    if (!next.add(listingId)) {
      next.remove(listingId);
    }
    _dismissedIds = next;
    if (userId.isNotEmpty) {
      await saveDismissedIds.execute(userId, next);
    }
    if (_simulatingListingId == listingId && next.contains(listingId)) {
      closeSimulator();
    }
    await _reanalyzeInIsolate();
  }

  void setShowDismissed(bool value) {
    if (_showDismissed == value) return;
    _showDismissed = value;
    _notify();
  }

  Future<void> openSimulator(SellerListingHealthItem item) async {
    final defaultTarget = item.suggestedPrice ?? double.parse((item.price * 0.85).toStringAsFixed(0));
    _simulatingListingId = item.id;
    _simulatedPrice = defaultTarget > 0 ? defaultTarget : item.price;
    await _runSimulation(item, _simulatedPrice);
  }

  void closeSimulator() {
    _simulatingListingId = null;
    _simulation = null;
    _simulating = false;
    _notify();
  }

  Future<void> updateSimulatedPrice(SellerListingHealthItem item, double newPrice) async {
    _simulatedPrice = newPrice;
    _notify();
    await _runSimulation(item, newPrice);
  }

  Future<void> _runSimulation(SellerListingHealthItem item, double newPrice) async {
    final gen = ++_simGeneration;
    _simulating = true;
    _notify();
    final sim = await simulatePriceDropInIsolate(
      item: item,
      newPrice: newPrice,
      staleDays: _staleDays,
      baselineCategorySellDays: baselineSellDays?.call(item.category),
    );
    if (_disposed || gen != _simGeneration || _simulatingListingId != item.id) return;
    _simulation = sim;
    _simulating = false;
    _notify();
  }

  /// Applies [newPrice] to [item] online via `PATCH /materials/:id`, or queues the edit in
  /// SQLite (`PendingActionKind.updateListingPrice`) if the device is offline.
  Future<String?> applyPriceDrop(SellerListingHealthItem item, double newPrice) async {
    if (_updatingIds.contains(item.id)) return null;
    // No server id yet (the listing is still waiting to be published): nothing to patch.
    if (!isUuid(item.id)) return itemSyncingMessage;
    _updatingIds.add(item.id);
    _statusMessage = null;
    _notify();

    try {
      final updated = await updateListingPrice.execute(item.id, newPrice);
      if (_disposed) return null;
      _localPriceOverrides[item.id] = updated.price;
      onMaterialUpdated?.call(updated);
      closeSimulator();
      _statusMessage = 'Updated "${item.title}" price online.';
      await _reanalyzeInIsolate();
      return null;
    } on NoConnectionException {
      if (userId.isEmpty) {
        return 'Log in to save price adjustments offline.';
      }
      await queuePriceUpdate.execute(
        ownerId: userId,
        materialId: item.id,
        newPrice: newPrice,
        listingTitle: item.title,
      );
      if (_disposed) return null;
      _localPriceOverrides[item.id] = newPrice;
      final localMatch = getMarketplaceListings().where((m) => m.id == item.id).firstOrNull;
      if (localMatch != null) {
        onMaterialUpdated?.call(localMatch.copyWith(price: newPrice, updatedAt: DateTime.now()));
      }
      closeSimulator();
      _statusMessage = 'Saved offline. "${item.title}" price will sync automatically when online.';
      await _reanalyzeInIsolate();
      return null;
    } on DataException catch (e) {
      if (_disposed) return e.message;
      _statusMessage = e.message;
      return e.message;
    } finally {
      _updatingIds.remove(item.id);
      _notify();
    }
  }

  Future<void> discardQueuedPriceUpdate(String listingId) async {
    final action = _pendingPriceActions[listingId];
    if (action == null) return;
    await discardPendingAction?.execute(action.id);
    _localPriceOverrides.remove(listingId);
    await _reanalyzeInIsolate();
  }

  void clearStatusMessage() {
    _statusMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingSub?.cancel();
    super.dispose();
  }
}
