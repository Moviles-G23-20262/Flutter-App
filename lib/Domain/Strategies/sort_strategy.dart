import '../Entities/material_entity.dart';

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

/// All strategies offered in the sort panel, in display order.
const List<SortStrategy> kSortStrategies = [
  RelevanceSortStrategy(),
  PriceAscSortStrategy(),
  PriceDescSortStrategy(),
  NewestSortStrategy(),
];
