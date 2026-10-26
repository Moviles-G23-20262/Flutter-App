import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/model/dto/price_stats_model.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/price_stats.dart';
import 'package:flutter_front_end/model/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/model/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/view/screens/new_listing_smart_screen.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/smart_listing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStats implements PriceStatsRepository {
  PriceStats? stats;
  Object? error;
  Completer<PriceStats>? hang;
  String? lastCategory;
  String? lastCondition;

  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) {
    lastCategory = category;
    lastCondition = condition;
    if (hang != null) return hang!.future;
    if (error != null) return Future.error(error!);
    return Future.value(stats);
  }
}

const _books = MaterialCategoryEnum.BOOKS;
const _good = MaterialConditionEnum.GOOD;

void main() {
  group('PriceStatsModel', () {
    test('reads the analytics response', () {
      final stats = PriceStatsModel.fromJson({
        'sample_size': 12,
        'p25': 20000.0,
        'median': 30000,
        'p75': 41000.5,
        'category': 'BOOKS',
        'scope': 'category',
      });
      expect(stats.sampleSize, 12);
      expect(stats.p25, 20000);
      expect(stats.median, 30000);
      expect(stats.p75, 41000.5);
    });
  });

  group('PriceEstimatorUseCase', () {
    late _FakeStats repo;
    late PriceEstimatorUseCase useCase;

    setUp(() {
      repo = _FakeStats();
      useCase = PriceEstimatorUseCase(repository: repo);
    });

    test('uses the real sales statistics when the backend has enough of them', () async {
      repo.stats = const PriceStats(sampleSize: 14, p25: 20000, median: 30000, p75: 42000);

      final estimate = await useCase.execute(category: _books, condition: _good);

      expect(estimate.source, PriceEstimateSource.realSales);
      expect(estimate.suggestedPrice, 30000);
      expect(estimate.p25, 20000);
      expect(estimate.p75, 42000);
      expect(estimate.sampleSize, 14);
      expect(estimate.isHeuristic, isFalse);
      expect(repo.lastCategory, 'BOOKS');
      expect(repo.lastCondition, 'GOOD');
    });

    test('exactly the minimum sample size is still trusted', () async {
      repo.stats = const PriceStats(sampleSize: PriceEstimatorUseCase.minSamples, p25: 1000, median: 2000, p75: 3000);

      final estimate = await useCase.execute(category: _books, condition: _good);

      expect(estimate.source, PriceEstimateSource.realSales);
    });

    test('falls back to the heuristic when the sample is too small', () async {
      repo.stats = const PriceStats(sampleSize: 4, p25: 1000, median: 2000, p75: 3000);

      final estimate = await useCase.execute(category: _books, condition: _good);

      expect(estimate.source, PriceEstimateSource.lowSampleHeuristic);
      expect(estimate.isHeuristic, isTrue);
      expect(estimate.sampleSize, 0);
      expect(estimate.suggestedPrice, isNot(2000));
    });

    test('falls back to the heuristic when there is no connection or the server fails', () async {
      for (final error in [Exception('offline'), StateError('500'), ArgumentError('bad url')]) {
        repo.error = error;
        final estimate = await useCase.execute(category: _books, condition: _good);
        expect(estimate.source, PriceEstimateSource.offlineHeuristic);
        expect(estimate.suggestedPrice, greaterThan(0));
      }
    });

    testWidgets('falls back when the server never answers', (tester) async {
      repo.hang = Completer<PriceStats>();
      PriceEstimate? estimate;
      useCase.execute(category: _books, condition: _good).then((e) => estimate = e);

      await tester.pump(PriceEstimatorUseCase.timeout + const Duration(seconds: 1));

      expect(estimate?.source, PriceEstimateSource.offlineHeuristic);
    });

    test('falls back when the backend returns inconsistent figures', () async {
      repo.stats = const PriceStats(sampleSize: 20, p25: 50000, median: 30000, p75: 10000);

      final estimate = await useCase.execute(category: _books, condition: _good);

      expect(estimate.source, PriceEstimateSource.offlineHeuristic);
    });

    test('without a repository it is heuristic only', () async {
      final estimate = await const PriceEstimatorUseCase().execute(category: _books, condition: _good);
      expect(estimate.source, PriceEstimateSource.offlineHeuristic);
    });
  });

  group('heuristic', () {
    const useCase = PriceEstimatorUseCase();

    test('a worse condition is cheaper and the range surrounds the price', () {
      PriceEstimate of(MaterialConditionEnum c) => useCase.heuristic(category: _books, condition: c);

      final prices = [
        of(MaterialConditionEnum.NEW),
        of(MaterialConditionEnum.LIKE_NEW),
        of(MaterialConditionEnum.GOOD),
        of(MaterialConditionEnum.FAIR),
      ];
      for (var i = 1; i < prices.length; i++) {
        expect(prices[i].suggestedPrice, lessThan(prices[i - 1].suggestedPrice));
      }
      for (final e in prices) {
        expect(e.p25, lessThan(e.suggestedPrice));
        expect(e.p75, greaterThan(e.suggestedPrice));
      }
    });

    test('every category and condition gives a positive, rounded price', () {
      for (final c in MaterialCategoryEnum.values) {
        for (final k in MaterialConditionEnum.values) {
          final e = useCase.heuristic(category: c, condition: k);
          expect(e.p25, greaterThan(0));
          expect(e.suggestedPrice % 1000, 0);
        }
      }
    });

    test('is deterministic: books in good condition', () {
      final e = useCase.heuristic(category: _books, condition: _good);
      expect(e.suggestedPrice, 29000); // 45.000 x 0.65 = 29.250 -> 29.000
      expect(e.p25, 24000); // x 0.82
      expect(e.p75, 35000); // x 1.18
    });
  });

  group('Smart listing screen', () {
    Future<_FakeStats> pump(WidgetTester tester) async {
      final repo = _FakeStats();
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: NewListingSmartScreen(
          appState: _NoApp(),
          viewModelFactory: () => SmartListingViewModel(
            estimator: PriceEstimatorUseCase(repository: repo),
          ),
        ),
      ));
      return repo;
    }

    Future<void> choose(WidgetTester tester) async {
      await tester.tap(find.text(MaterialCategoryEnum.BOOKS.displayName));
      await tester.tap(find.text(MaterialConditionEnum.GOOD.displayName));
      await tester.pump();
    }

    testWidgets('shows the real-sales estimate and applies it with one tap', (tester) async {
      final repo = await pump(tester);
      repo.stats = const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);

      await choose(tester);
      await tester.tap(find.text('Suggest Fair Price'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('estimate-price')), findsOneWidget);
      expect(find.text('Based on 9 real sales'), findsOneWidget);
      expect(find.textContaining('\$20.000 COP'), findsOneWidget);
      expect(find.textContaining('\$42.000 COP'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('apply-suggested-price')));
      await tester.tap(find.byKey(const Key('apply-suggested-price')));
      await tester.pump();

      final field = tester.widget<TextField>(find.descendant(
        of: find.byKey(const Key('smart-price-field')),
        matching: find.byType(TextField),
      ));
      expect(field.controller!.text, '30000');
    });

    testWidgets('offline, it still answers with a labelled heuristic estimate', (tester) async {
      final repo = await pump(tester);
      repo.error = Exception('no connection');

      await choose(tester);
      await tester.tap(find.text('Suggest Fair Price'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('estimate-price')), findsOneWidget);
      expect(find.textContaining('Heuristic estimate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the button needs a category and a condition', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Suggest Fair Price'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('estimate-price')), findsNothing);
    });

    testWidgets('changing the condition clears the estimate', (tester) async {
      final repo = await pump(tester);
      repo.stats = const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
      await choose(tester);
      await tester.tap(find.text('Suggest Fair Price'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('estimate-price')), findsOneWidget);

      await tester.tap(find.text(MaterialConditionEnum.FAIR.displayName));
      await tester.pump();

      expect(find.byKey(const Key('estimate-price')), findsNothing);
    });
  });
}

// The screen only touches appState when navigating back, which these tests never do.
class _NoApp implements AppViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
