import 'dart:async';

import 'package:flutter/foundation.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/new_listing_data.dart';
import '../model/entities/pending_items.dart';
import '../model/entities/wishlist_item_entity.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/pending_listing_use_cases.dart';
import '../model/strategies/sort_strategy.dart';

/// Listings and favorites, shared by Home, Search, Detail and the Seller Hub.
class MarketplaceViewModel extends ChangeNotifier {
  final GetMaterialsUseCase getMaterials;
  final CreateListingUseCase createListing;
  final GetWishlistUseCase getWishlist;
  final AddToWishlistUseCase addToWishlist;
  final RemoveFromWishlistUseCase removeFromWishlist;
  final WatchPendingListingsUseCase? watchPendingListings;
  final DiscardPendingListingUseCase? discardPendingListing;

  MarketplaceViewModel({
    required this.getMaterials,
    required this.createListing,
    required this.getWishlist,
    required this.addToWishlist,
    required this.removeFromWishlist,
    this.watchPendingListings,
    this.discardPendingListing,
  });

  List<PendingListing> _pendingListings = const [];
  StreamSubscription<List<PendingListing>>? _pendingSubscription;
  final Set<String> _discarded = {};

  List<MaterialEntity> _materials = const [];
  List<WishlistItemEntity> _wishlist = const [];
  DateTime? _wishlistSavedAt;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  final Set<String> _togglingFavorites = {};

  /// Bumped on [clear] so answers that arrive after a sign-out are dropped.
  int _generation = 0;

  List<MaterialEntity> get materials => _materials;
  List<MaterialEntity> get availableMaterials =>
      _materials.where((m) => m.isAvailable).toList(growable: false);
  List<WishlistItemEntity> get wishlist => _wishlist;

  /// Set while the favorites shown are the copy saved on the phone (offline): when it was saved.
  DateTime? get wishlistSavedAt => _wishlistSavedAt;
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
      final published = _pendingListings.any((l) => !stillThere.contains(l.id) && !_discarded.remove(l.id));
      _pendingListings = listings;
      notifyListeners();
      if (published) load();
    }, onError: (_) {});
  }

  /// The user gives up on a listing that is waiting or was refused.
  Future<void> discardPending(String listingId) async {
    _discarded.add(listingId);
    await discardPendingListing?.execute(listingId);
  }

  List<MaterialEntity> listingsOf(String sellerId) =>
      _materials.where((m) => m.sellerId == sellerId).toList(growable: false);

  bool isFavorite(String materialId) => _wishlist.any((w) => w.materialId == materialId);

  Future<void> load() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();

    // Both start at once. Favorites load on their own, so the saved copy still shows when the
    // listings cannot be loaded offline.
    final favorites = _loadWishlist(generation);
    try {
      final materials = await getMaterials.execute();
      if (generation != _generation) return;
      _materials = materials;
    } on DataException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'Unexpected error. Please try again.';
    }
    await favorites;
    if (generation != _generation) return;
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
  }

  Future<void> _loadWishlist(int generation) async {
    try {
      final result = await getWishlist.execute();
      if (generation != _generation) return;
      _wishlist = result.items;
      _wishlistSavedAt = result.savedAt;
    } on DataException catch (e) {
      if (generation == _generation) _error ??= e.message;
    } catch (_) {
      if (generation == _generation) _error ??= 'Unexpected error. Please try again.';
    }
  }

  /// Heart tapped. Updates instantly and rolls back if the server refuses.
  /// Offline the server cannot confirm it, so it is rolled back and the user is told why.
  /// Returns an error message to show, or `null` on success.
  Future<String?> toggleFavorite(String materialId) async {
    if (!_togglingFavorites.add(materialId)) return null;
    final generation = _generation;
    final before = _wishlist;
    final existing = before.where((w) => w.materialId == materialId).firstOrNull;

    try {
      if (existing != null) {
        _wishlist = before.where((w) => w.id != existing.id).toList();
        notifyListeners();
        await removeFromWishlist.execute(existing.id);
      } else {
        _wishlist = [
          WishlistItemEntity(
            id: 'pending:$materialId',
            userId: '',
            materialId: materialId,
            material: _materials.where((m) => m.id == materialId).firstOrNull,
            createdAt: DateTime.now(),
          ),
          ...before,
        ];
        notifyListeners();
        final saved = await addToWishlist.execute(materialId);
        if (generation == _generation) {
          _wishlist = _wishlist.map((w) => w.materialId == materialId ? saved : w).toList();
          notifyListeners();
        }
      }
      return null;
    } on DataException catch (e) {
      if (generation == _generation) {
        _wishlist = before;
        notifyListeners();
      }
      return e.message;
    } finally {
      _togglingFavorites.remove(materialId);
    }
  }


  String _searchQuery = '';
  MaterialCategoryEnum? _searchCategory;
  MaterialConditionEnum? _searchCondition;
  double _maxSearchPrice = 200;
  SortStrategy _searchSort = const RelevanceSortStrategy();

  String get searchQuery => _searchQuery;
  MaterialCategoryEnum? get searchCategory => _searchCategory;
  MaterialConditionEnum? get searchCondition => _searchCondition;
  double get maxSearchPrice => _maxSearchPrice;
  SortStrategy get searchSort => _searchSort;

  bool get hasSearchFilters =>
      _searchQuery.trim().isNotEmpty ||
      _searchCategory != null ||
      _searchCondition != null ||
      _maxSearchPrice < 200 ||
      _searchSort.id != 'relevance';

  List<MaterialEntity> get filteredMaterials {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = availableMaterials.where((material) {
      if (_searchCategory != null &&
          material.category != _searchCategory) {
        return false;
      }

      if (_searchCondition != null &&
          material.condition != _searchCondition) {
        return false;
      }

      if (material.price > _maxSearchPrice) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchesTitle =
            material.title.toLowerCase().contains(query);

        final matchesDescription =
            material.description.toLowerCase().contains(query);

        final matchesCourse =
            material.courseCode?.toLowerCase().contains(query) ?? false;

        final matchesCategory =
            material.category.displayName.toLowerCase().contains(query);

        if (!matchesTitle &&
            !matchesDescription &&
            !matchesCourse &&
            !matchesCategory) {
          return false;
        }
      }

      return true;
    }).toList();

    return _searchSort.sort(filtered);
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
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
    notifyListeners();
    return created;
  }

  void clear() {
    _generation++;
    _pendingSubscription?.cancel();
    _pendingSubscription = null;
    _pendingListings = const [];
    _discarded.clear();
    _materials = const [];
    _wishlist = const [];
    _wishlistSavedAt = null;
    _loading = false;
    _loadedOnce = false;
    _error = null;
    _togglingFavorites.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    super.dispose();
  }
}
