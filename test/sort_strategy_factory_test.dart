import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_front_end/Domain/Strategies/sort_strategy.dart';

void main() {
  group('SortStrategyFactory', () {
    test('create returns the matching strategy for every SortKind', () {
      expect(SortStrategyFactory.create(SortKind.relevance), isA<RelevanceSortStrategy>());
      expect(SortStrategyFactory.create(SortKind.priceAsc), isA<PriceAscSortStrategy>());
      expect(SortStrategyFactory.create(SortKind.priceDesc), isA<PriceDescSortStrategy>());
      expect(SortStrategyFactory.create(SortKind.sellerRating), isA<SellerRatingSortStrategy>());
      expect(SortStrategyFactory.create(SortKind.newest), isA<NewestSortStrategy>());
    });

    test('all lists one strategy per kind in display order with unique ids', () {
      final all = SortStrategyFactory.all;
      expect(all.length, SortKind.values.length);
      expect(all.first.id, 'relevance');
      expect(all.map((s) => s.id).toSet().length, all.length);
    });

    test('fromId resolves known ids and falls back to relevance', () {
      expect(SortStrategyFactory.fromId('price-asc'), isA<PriceAscSortStrategy>());
      expect(SortStrategyFactory.fromId('newest'), isA<NewestSortStrategy>());
      expect(SortStrategyFactory.fromId('unknown'), isA<RelevanceSortStrategy>());
    });
  });
}
