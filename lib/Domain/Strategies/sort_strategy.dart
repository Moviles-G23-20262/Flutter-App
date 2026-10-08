import '../Entities/material_entity.dart';

// Strictly enforces OCP (Open-Closed Principle) for sorting strategies. New strategies can be added without modifying existing code.
// we can extend the business logic infinitely without ever touching the presentation layer.
// ->>>>>>> HW CAMERA SENSOR: lib/Presentation/Screens/new_listing_smart_screen.dart. Between lines 35, the _pick method directly invokes ImagePicker().pickImage using ImageSource.camera.



/// Strategy contract for ordering a list of marketplace listings.
///
/// Implementations must not mutate the input list.
abstract class SortStrategy {
  const SortStrategy();

  /// Stable identifier used by the UI to select a strategy.
  String get id;

  /// Human-readable label for display in the UI.
  String get label;

  /// Returns a new list with [items] ordered by this strategy.
  List<MaterialEntity> sort(List<MaterialEntity> items);
}

/// Keeps the original (relevance) order.
class RelevanceSortStrategy extends SortStrategy {
  const RelevanceSortStrategy();

  @override
  String get id => 'relevance';

  @override
  String get label => 'Relevance';

  @override
  List<MaterialEntity> sort(List<MaterialEntity> items) => List.of(items);
}

/// Cheapest first.
class PriceAscSortStrategy extends SortStrategy {
  const PriceAscSortStrategy();

  @override
  String get id => 'price-asc';

  @override
  String get label => 'Price low';

  @override
  List<MaterialEntity> sort(List<MaterialEntity> items) =>
      List.of(items)..sort((a, b) => a.price.compareTo(b.price));
}

/// Most expensive first.
class PriceDescSortStrategy extends SortStrategy {
  const PriceDescSortStrategy();

  @override
  String get id => 'price-desc';

  @override
  String get label => 'Price high';

  @override
  List<MaterialEntity> sort(List<MaterialEntity> items) =>
      List.of(items)..sort((a, b) => b.price.compareTo(a.price));
}

/// Most recently created first.
class NewestSortStrategy extends SortStrategy {
  const NewestSortStrategy();

  @override
  String get id => 'newest';

  @override
  String get label => 'Newest';

  @override
  List<MaterialEntity> sort(List<MaterialEntity> items) =>
      List.of(items)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Highest seller rating first.
class SellerRatingSortStrategy extends SortStrategy {
  const SellerRatingSortStrategy();

  @override
  String get id => 'seller-rating';

  @override
  String get label => 'Rating';

  @override
  List<MaterialEntity> sort(List<MaterialEntity> items) {
    return List.of(items)
      ..sort((a, b) {
        final aRating = a.seller?.rating ?? 0;
        final bRating = b.seller?.rating ?? 0;

        final ratingCompare = bRating.compareTo(aRating);

        // If ratings are equal, newest listing first.
        if (ratingCompare != 0) return ratingCompare;

        return b.createdAt.compareTo(a.createdAt);
      });
  }
}

/// All strategies offered in the sort panel, in display order.
const List<SortStrategy> kSortStrategies = [
  RelevanceSortStrategy(),
  PriceAscSortStrategy(),
  PriceDescSortStrategy(),
  SellerRatingSortStrategy(),
  NewestSortStrategy(),
];
