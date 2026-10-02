import 'package:flutter/foundation.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/new_listing_data.dart';
import '../../Domain/Entities/wishlist_item_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/use_cases/marketplace_use_cases.dart';
import '../../Domain/Strategies/sort_strategy.dart';

/// Listings and favorites, shared by Home, Search, Detail and the Seller Hub.
class MarketplaceState extends ChangeNotifier {
  final GetMaterialsUseCase getMaterials;
  final CreateListingUseCase createListing;
  final GetWishlistUseCase getWishlist;
  final AddToWishlistUseCase addToWishlist;
  final RemoveFromWishlistUseCase removeFromWishlist;

  MarketplaceState({
    required this.getMaterials,
    required this.createListing,
    required this.getWishlist,
    required this.addToWishlist,
    required this.removeFromWishlist,
  });

  List<MaterialEntity> _materials = const [];
  List<WishlistItemEntity> _wishlist = const [];
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
  bool get isLoading => _loading;

  /// True until the first load finished (successfully or not): show a spinner, not an empty state.
  bool get isFirstLoad => !_loadedOnce;
  String? get error => _error;

  List<MaterialEntity> listingsOf(String sellerId) =>
      _materials.where((m) => m.sellerId == sellerId).toList(growable: false);

  bool isFavorite(String materialId) => _wishlist.any((w) => w.materialId == materialId);

  Future<void> load() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([getMaterials.execute(), getWishlist.execute()]);
      if (generation != _generation) return;
      _materials = results[0] as List<MaterialEntity>;
      _wishlist = results[1] as List<WishlistItemEntity>;
    } on DataException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'Unexpected error. Please try again.';
    }
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
  }

  /// Heart tapped. Updates instantly and rolls back if the server refuses.
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
    _materials = const [];
    _wishlist = const [];
    _loading = false;
    _loadedOnce = false;
    _error = null;
    _togglingFavorites.clear();
    notifyListeners();
  }
}
