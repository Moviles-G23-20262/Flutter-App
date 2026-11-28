import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/new_listing_data.dart';
import '../model/entities/pending_items.dart';
import '../model/rules/client_id.dart';
import '../model/entities/wishlist_item_entity.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/pending_listing_use_cases.dart';
import '../model/strategies/sort_strategy.dart';
import '../model/entities/time_to_sell.dart';
import '../model/use_cases/get_time_to_sell_use_case.dart';

/// Listings and favorites, shared by Home, Search, Detail and the Seller Hub.
class MarketplaceViewModel extends ChangeNotifier {
  final GetMaterialsUseCase getMaterials;
  final CreateListingUseCase createListing;
  final GetWishlistUseCase getWishlist;
  final AddToWishlistUseCase addToWishlist;
  final RemoveFromWishlistUseCase removeFromWishlist;
  final WatchPendingListingsUseCase? watchPendingListings;
  final RetryPendingListingUseCase? retryPendingListing;
  final DiscardPendingListingUseCase? discardPendingListing;
  final GetTimeToSellUseCase? getTimeToSell;

  MarketplaceViewModel({
    required this.getMaterials,
    required this.createListing,
    required this.getWishlist,
    required this.addToWishlist,
    required this.removeFromWishlist,
    this.watchPendingListings,
    this.retryPendingListing,
    this.discardPendingListing,
    this.getTimeToSell,
  });

  List<PendingListing> _pendingListings = const [];
  StreamSubscription<List<PendingListing>>? _pendingSubscription;
  final Set<String> _discarded = {};
  final StreamController<String> _publishedNotices = StreamController<String>.broadcast();

  /// One message per queued listing the server accepted ("X was published"). The queue only drops
  /// a row after the server confirmed it (or after the user discards it, which is not reported),
  /// so the message is shown only for a real publish. The shell turns it into a SnackBar.
  Stream<String> get publishedNotices => _publishedNotices.stream;

  List<MaterialEntity> _materials = const [];
  List<MaterialEntity>? _availableMaterialsCache;
  List<WishlistItemEntity> _wishlist = const [];
  Set<String>? _wishlistIdsCache;
  DateTime? _wishlistSavedAt;
  DateTime? _materialsSavedAt;
  bool _loading = false;
  bool _loadedOnce = false;
  bool _wishlistLoading = false;
  String? _wishlistError;
  String? _error;
  TimeToSellInsight? _timeToSell;
  final Set<String> _togglingFavorites = {};

  /// Bumped on [clear] so answers that arrive after a sign-out are dropped.
  int _generation = 0;
  int _loadRequest = 0;

  List<MaterialEntity> get materials => _materials;
  List<MaterialEntity> get availableMaterials =>
      _availableMaterialsCache ??= List.unmodifiable(_materials.where((m) => m.isAvailable));
  List<WishlistItemEntity> get wishlist => _wishlist;

  void _setWishlist(List<WishlistItemEntity> items) {
    _wishlist = items;
    _wishlistIdsCache = null;
  }

  /// Set while the favorites shown are the copy saved on the phone (offline): when it was saved.
  DateTime? get wishlistSavedAt => _wishlistSavedAt;
  bool get isWishlistLoading => _wishlistLoading;
  String? get wishlistError => _wishlistError;

  /// Set while the listings shown are the copy saved on the phone (offline): when it was saved.
  DateTime? get materialsSavedAt => _materialsSavedAt;
  bool get isOffline => _materialsSavedAt != null;
  TimeToSellInsight? get timeToSell => _timeToSell;

  bool get isLoading => _loading;

  /// True until the first load finished (successfully or not): show a spinner, not an empty state.
  bool get isFirstLoad => !_loadedOnce;
  String? get error => _error;

  /// The signed-in user's listings saved on the phone and not published yet (oldest first):
  /// waiting for a connection, or refused by the server ([PendingListing.isRefused]).
  List<PendingListing> get pendingListings => _pendingListings;

  /// Follows [userId]'s queued listings. When one leaves the queue because it was published,
  /// the listings are read again, so it shows up as a normal one.
  void watchPending(String userId) {
    final watch = watchPendingListings;
    if (watch == null) return;
    _pendingSubscription?.cancel();
    final generation = _generation;
    _pendingSubscription = watch.execute(userId).listen((listings) {
      if (generation != _generation) return;
      final stillThere = {for (final l in listings) l.id};
      // Gone from the queue and not discarded by the user: the server confirmed it.
      final published = [
        for (final l in _pendingListings)
          if (!stillThere.contains(l.id) && !_discarded.remove(l.id)) l,
      ];
      _pendingListings = listings;
      notifyListeners();
      if (published.isNotEmpty) {
        for (final l in published) {
          if (!_publishedNotices.isClosed) _publishedNotices.add(publishedNoticeFor(l));
        }
        load();
      }
    }, onError: (_) {});
  }

  /// Text of the notice shown once a listing saved offline was published.
  static String publishedNoticeFor(PendingListing listing) => '"${listing.title}" is now published.';

  /// Moves a refused listing back to `waiting` and tries publishing it again.
  Future<void> retryPending(String listingId) async {
    await retryPendingListing?.execute(listingId);
  }

  /// The user gives up on a listing that is waiting or was refused.
  Future<void> discardPending(String listingId) async {
    _discarded.add(listingId);
    await discardPendingListing?.execute(listingId);
  }

  List<MaterialEntity> listingsOf(String sellerId) =>
      _materials.where((m) => m.sellerId == sellerId).toList(growable: false);

  /// O(1) favorite membership lookup backed by a lazily materialized [Set<String>] (MO4).
  bool isFavorite(String materialId) =>
      (_wishlistIdsCache ??= {for (final w in _wishlist) w.materialId}).contains(materialId);

  Future<void> load() async {
    final request = ++_loadRequest;
    _loading = true;
    _wishlistLoading = true;
    _wishlistError = null;
    _error = null;
    _timeToSell = null;
    notifyListeners();

    // Both start at once. Favorites load on their own, so the saved copy still shows when the
    // listings cannot be loaded offline.
    final favorites = _loadWishlist(request);
    // Sabrina OFFLINE - MarketplaceViewModel.load() fetches materials, wishlist, and BQ11 in parallel, saves _materialsSavedAt so the UI knows the cache age
    final timeToSell = _loadTimeToSell(request);
    try {
      final result = await getMaterials.executeCached();
      if (request != _loadRequest) return;
      _materials = result.items;
      _availableMaterialsCache = null;
      _materialsSavedAt = result.savedAt;
    } on DataException catch (e) {
      if (request != _loadRequest) return;
      _error = e.message;
    } catch (_) {
      if (request != _loadRequest) return;
      _error = 'Unexpected error. Please try again.';
    }
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
    await favorites;
    await timeToSell;
  }

  Future<void> _loadWishlist(int request) async {
    try {
      final result = await getWishlist.execute();
      if (request != _loadRequest) return;
      _setWishlist(result.items);
      _wishlistSavedAt = result.savedAt;
    } on DataException catch (e) {
      if (request == _loadRequest) _wishlistError = e.message;
    } catch (_) {
      if (request == _loadRequest) _wishlistError = 'Unexpected error. Please try again.';
    } finally {
      if (request == _loadRequest) {
        _wishlistLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadTimeToSell(int request) async {
    final useCase = getTimeToSell;
    if (useCase == null) return;
    try {
      final result = await useCase.execute();
      if (request != _loadRequest) return;
      _timeToSell = result;
      notifyListeners();
    } catch (_) {}
  }

  /// Shown instead of calling the server for a listing it does not know yet.
  static const String syncingMessage = itemSyncingMessage;

  /// A listing the user made offline is still waiting on the phone: the server has no such
  /// listing yet, so favoriting, chatting or buying it would fail.
  bool isSyncing(String materialId) => _pendingListings.any((l) => l.id == materialId);

  /// `null` when [materialId] is a listing id the server knows and can be sent; otherwise the
  /// message to show instead of making a call that would end in a 400 ("uuid is expected") or a
  /// 404. Covers an empty or non-UUID id and a listing still waiting in the offline queue.
  String? serverIdProblem(String materialId) =>
      isUuid(materialId) && !isSyncing(materialId) ? null : syncingMessage;

  /// Id prefix of the placeholder shown while a favorite is being saved. It is not an id the
  /// server knows: sending it in `DELETE /wishlist-items/:id` is refused ("uuid is expected").
  static const String _placeholderPrefix = 'temp-';

  static bool _isPlaceholder(WishlistItemEntity item) => item.id.startsWith(_placeholderPrefix);

  /// Heart tapped. Updates instantly and rolls back if the server refuses.
  /// Offline the server cannot confirm it, so it is rolled back and the user is told why.
  /// Returns an error message to show, or `null` on success.
  Future<String?> toggleFavorite(String materialId) async {
    final notReady = serverIdProblem(materialId);
    if (notReady != null) return notReady;
    if (!_togglingFavorites.add(materialId)) return null;
    final generation = _generation;
    final existing = _wishlist.where((w) => w.materialId == materialId).firstOrNull;

    // Optimistic: toggle right away.
    if (existing != null) {
      _setWishlist(_wishlist.where((w) => w.materialId != materialId).toList(growable: false));
    } else {
      _setWishlist([
        WishlistItemEntity(
          id: '$_placeholderPrefix$materialId',
          userId: '',
          materialId: materialId,
          createdAt: DateTime.now(),
        ),
        ..._wishlist,
      ]);
    }
    notifyListeners();

    try {
      if (existing != null) {
        // A placeholder was never saved on the server (its save failed or was dropped), so there
        // is nothing to delete there; asking would be a 400 for an id that is not a UUID.
        if (!_isPlaceholder(existing)) await removeFromWishlist.execute(existing.id);
      } else {
        final created = await addToWishlist.execute(materialId);
        if (generation == _generation) {
          _setWishlist([created, ..._wishlist.where((w) => w.materialId != materialId)]);
          notifyListeners();
        }
      }
      return null;
    } on DataException catch (e) {
      if (generation == _generation) {
        // Undo only this heart. Restoring a snapshot taken before the tap would also undo a
        // favorite saved meanwhile, and bring its placeholder back.
        _setWishlist(
          existing != null
              ? [existing, ..._wishlist.where((w) => w.materialId != materialId)]
              : _wishlist.where((w) => w.materialId != materialId).toList(growable: false),
        );
        notifyListeners();
      }
      return e.message;
    } finally {
      _togglingFavorites.remove(materialId);
    }
  }

  // ── Search State ──────────────────────────────────────────────────────────

  String _searchQuery = '';
  MaterialCategoryEnum? _searchCategory;
  MaterialConditionEnum? _searchCondition;
  double _maxSearchPrice = 200;
  SortStrategy _searchSort = const RelevanceSortStrategy();

  // MO4 memoization state for [filteredSearchResults].
  List<MaterialEntity>? _filteredSource;
  String? _filteredQuery;
  MaterialCategoryEnum? _filteredCategory;
  MaterialConditionEnum? _filteredCondition;
  double? _filteredMaxPrice;
  String? _filteredSortId;
  List<MaterialEntity> _filteredResultsCache = const [];
  int _searchFilterComputations = 0;

  /// Counts how many times [filteredSearchResults] actually executed a filter + sort pass (MO4).
  @visibleForTesting
  int get searchFilterComputations => _searchFilterComputations;

  String get searchQuery => _searchQuery;
  MaterialCategoryEnum? get searchCategory => _searchCategory;
  MaterialConditionEnum? get searchCondition => _searchCondition;
  double get maxSearchPrice => _maxSearchPrice;
  SortStrategy get searchSort => _searchSort;

  /// Memoized filter & sort over [_materials] (MO4). Re-runs only when the backing list or
  /// any search filter/sort input changes, avoiding redundant allocations on unrelated rebuilds.
  List<MaterialEntity> get filteredSearchResults {
    final sortId = _searchSort.id;
    if (identical(_materials, _filteredSource) &&
        _filteredQuery == _searchQuery &&
        _filteredCategory == _searchCategory &&
        _filteredCondition == _searchCondition &&
        _filteredMaxPrice == _maxSearchPrice &&
        _filteredSortId == sortId) {
      return _filteredResultsCache;
    }

    developer.Timeline.startSync('Marketplace.filterSearch');
    try {
      _searchFilterComputations++;
      final hasQuery = _searchQuery.isNotEmpty;
      final q = hasQuery ? _searchQuery.toLowerCase() : '';
      final list = <MaterialEntity>[];
      for (var i = 0; i < _materials.length; i++) {
        final m = _materials[i];
        if (!m.isAvailable) continue;
        if (_searchCategory != null && m.category != _searchCategory) continue;
        if (_searchCondition != null && m.condition != _searchCondition) continue;
        if (m.price > _maxSearchPrice) continue;
        if (hasQuery) {
          final matchTitle = m.title.toLowerCase().contains(q);
          final matchDesc = m.description.toLowerCase().contains(q);
          final matchCourse = m.courseCode?.toLowerCase().contains(q) ?? false;
          if (!matchTitle && !matchDesc && !matchCourse) continue;
        }
        list.add(m);
      }

      _filteredSource = _materials;
      _filteredQuery = _searchQuery;
      _filteredCategory = _searchCategory;
      _filteredCondition = _searchCondition;
      _filteredMaxPrice = _maxSearchPrice;
      _filteredSortId = sortId;
      return _filteredResultsCache = List.unmodifiable(_searchSort.sort(list));
    } finally {
      developer.Timeline.finishSync();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSearchCategory(MaterialCategoryEnum? value) {
    _searchCategory = value;
    notifyListeners();
  }

  void setSearchCondition(MaterialConditionEnum? value) {
    _searchCondition = value;
    notifyListeners();
  }

  void setMaxSearchPrice(double value) {
    _maxSearchPrice = value;
    notifyListeners();
  }

  void setSearchSort(SortStrategy strategy) {
    _searchSort = strategy;
    notifyListeners();
  }

  void resetSearchFilters() {
    _searchQuery = '';
    _searchCategory = null;
    _searchCondition = null;
    _maxSearchPrice = 200;
    _searchSort = const RelevanceSortStrategy();
    notifyListeners();
  }

  /// Uploads the photos and creates the listing. Throws [DataException] with a message to show.
  Future<MaterialEntity> publish(NewListingData data) async {
    final created = await createListing.execute(data);
    _materials = [created, ..._materials];
    _availableMaterialsCache = null;
    notifyListeners();
    return created;
  }

  /// Replaces an existing listing in memory after a price drop or offline edit.
  void replaceMaterial(MaterialEntity updated) {
    final idx = _materials.indexWhere((m) => m.id == updated.id);
    if (idx < 0) return;
    final copy = List<MaterialEntity>.of(_materials);
    copy[idx] = updated;
    _materials = copy;
    _availableMaterialsCache = null;
    notifyListeners();
  }

  void clear() {
    _generation++;
    _loadRequest++;
    _pendingSubscription?.cancel();
    _pendingSubscription = null;
    _pendingListings = const [];
    _discarded.clear();
    _materials = const [];
    _availableMaterialsCache = null;
    _setWishlist(const []);
    _wishlistSavedAt = null;
    _wishlistLoading = false;
    _wishlistError = null;
    _materialsSavedAt = null;
    _loading = false;
    _loadedOnce = false;
    _error = null;
    _timeToSell = null;
    _togglingFavorites.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _loadRequest++;
    _pendingSubscription?.cancel();
    _publishedNotices.close();
    super.dispose();
  }
}
