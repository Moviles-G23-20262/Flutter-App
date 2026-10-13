import 'dart:async';

import 'package:flutter_front_end/Domain/Entities/material_entity.dart';
import 'package:flutter_front_end/Domain/Entities/price_stats.dart';
import 'package:flutter_front_end/Domain/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/Domain/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/Presentation/ViewModels/smart_listing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStats implements PriceStatsRepository {
  PriceStats? stats;
  Object? error;
  Completer<PriceStats>? pending;
  int calls = 0;
  String? lastCategory;
  String? lastCondition;

  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) {
    calls++;
    lastCategory = category;
    lastCondition = condition;
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value(stats);
  }
}

/// A use case that breaks in a way the real one never should.
class _ExplodingEstimator extends PriceEstimatorUseCase {
  @override
  Future<PriceEstimate> execute({
    required MaterialCategoryEnum category,
    required MaterialConditionEnum condition,
  }) async =>
      throw StateError('unexpected');
}

void main() {
  late _FakeStats repo;
  late SmartListingViewModel vm;
  late int notified;

  setUp(() {
    repo = _FakeStats();
    vm = SmartListingViewModel(estimator: PriceEstimatorUseCase(repository: repo));
    notified = 0;
    vm.addListener(() => notified++);
  });

  tearDown(() => vm.dispose());

  void choose() {
    vm.setCategory('BOOKS');
    vm.setCondition('GOOD');
    notified = 0;
  }

  group('initial state', () {
    test('nothing chosen, nothing estimated, not loading', () {
      expect(vm.selectedCategory, isNull);
      expect(vm.selectedCondition, isNull);
      expect(vm.suggestedPrice, isNull);
      expect(vm.p25, isNull);
      expect(vm.p75, isNull);
      expect(vm.sampleSize, 0);
      expect(vm.isFallback, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
      expect(vm.hasEstimate, isFalse);
      expect(vm.canEstimate, isFalse);
    });

    test('estimating without both choices does nothing', () async {
      vm.setCategory('BOOKS');
      notified = 0;

      await vm.estimatePrice();

      expect(repo.calls, 0);
      expect(vm.hasEstimate, isFalse);
      expect(notified, 0);
    });
  });

  group('choosing category and condition', () {
    test('stores each choice and notifies the listeners', () {
      vm.setCategory('CALCULATORS');
      expect(vm.selectedCategory, 'CALCULATORS');
      expect(notified, 1);

      vm.setCondition('LIKE_NEW');
      expect(vm.selectedCondition, 'LIKE_NEW');
      expect(notified, 2);
      expect(vm.canEstimate, isTrue);
    });

    test('choosing the same value again or an unknown one changes nothing', () {
      vm.setCategory('BOOKS');
      notified = 0;

      vm.setCategory('BOOKS');
      vm.setCategory('SPACESHIPS');
      vm.setCondition('BROKEN');

      expect(vm.selectedCategory, 'BOOKS');
      expect(vm.selectedCondition, isNull);
      expect(notified, 0);
    });

    test('a new choice discards the current estimate', () async {
      choose();
      repo.stats = const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
      await vm.estimatePrice();
      expect(vm.hasEstimate, isTrue);

      vm.setCondition('FAIR');

      expect(vm.hasEstimate, isFalse);
      expect(vm.suggestedPrice, isNull);
    });
  });

  group('estimatePrice', () {
    test('real sales: goes loading, then fills the price, range and sample size', () async {
      choose();
      repo.stats = const PriceStats(sampleSize: 14, p25: 20000, median: 30000, p75: 42000);
      final loadingStates = <bool>[];
      vm.addListener(() => loadingStates.add(vm.isLoading));

      await vm.estimatePrice();

      expect(loadingStates, [true, false]);
      expect(vm.isLoading, isFalse);
      expect(vm.suggestedPrice, 30000);
      expect(vm.p25, 20000);
      expect(vm.p75, 42000);
      expect(vm.sampleSize, 14);
      expect(vm.isFallback, isFalse);
      expect(vm.source, PriceEstimateSource.realSales);
      expect(vm.errorMessage, isNull);
      expect(repo.lastCategory, 'BOOKS');
      expect(repo.lastCondition, 'GOOD');
    });

    test('fewer than 5 sales: falls back to the heuristic', () async {
      choose();
      repo.stats = const PriceStats(sampleSize: 4, p25: 1000, median: 2000, p75: 3000);

      await vm.estimatePrice();

      expect(vm.isFallback, isTrue);
      expect(vm.source, PriceEstimateSource.lowSampleHeuristic);
      expect(vm.sampleSize, 0);
      expect(vm.suggestedPrice, 29000); // books in good condition
      expect(vm.p25, lessThan(vm.suggestedPrice!));
      expect(vm.p75, greaterThan(vm.suggestedPrice!));
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('network failure: falls back to the heuristic without an error', () async {
      choose();
      repo.error = Exception('no connection');

      await vm.estimatePrice();

      expect(vm.isFallback, isTrue);
      expect(vm.source, PriceEstimateSource.offlineHeuristic);
      expect(vm.suggestedPrice, greaterThan(0));
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('an unexpected failure becomes an error message, never an exception', () async {
      final broken = SmartListingViewModel(estimator: _ExplodingEstimator())
        ..setCategory('BOOKS')
        ..setCondition('GOOD');
      addTearDown(broken.dispose);

      await expectLater(broken.estimatePrice(), completes);

      expect(broken.errorMessage, isNotNull);
      expect(broken.hasEstimate, isFalse);
      expect(broken.isLoading, isFalse);
    });

    test('a retry after an error clears it', () async {
      final flaky = _FlakyEstimator();
      final model = SmartListingViewModel(estimator: flaky)
        ..setCategory('BOOKS')
        ..setCondition('GOOD');
      addTearDown(model.dispose);

      await model.estimatePrice();
      expect(model.errorMessage, isNotNull);

      await model.estimatePrice();
      expect(model.errorMessage, isNull);
      expect(model.hasEstimate, isTrue);
    });

    test('ignores a second request while one is running', () async {
      choose();
      repo.pending = Completer<PriceStats>();

      final first = vm.estimatePrice();
      await vm.estimatePrice();
      repo.pending!.complete(const PriceStats(sampleSize: 9, p25: 1000, median: 2000, p75: 3000));
      await first;

      expect(repo.calls, 1);
      expect(vm.suggestedPrice, 2000);
    });

    test('an answer that arrives after the user changed the choice is dropped', () async {
      choose();
      repo.pending = Completer<PriceStats>();

      final running = vm.estimatePrice();
      vm.setCondition('FAIR');
      repo.pending!.complete(const PriceStats(sampleSize: 9, p25: 1000, median: 2000, p75: 3000));
      await running;

      expect(vm.hasEstimate, isFalse);
      expect(vm.isLoading, isFalse);
    });

    test('an answer that arrives after dispose does not notify', () async {
      final model = SmartListingViewModel(estimator: PriceEstimatorUseCase(repository: repo))
        ..setCategory('BOOKS')
        ..setCondition('GOOD');
      repo.pending = Completer<PriceStats>();

      final running = model.estimatePrice();
      model.dispose();
      repo.pending!.complete(const PriceStats(sampleSize: 9, p25: 1000, median: 2000, p75: 3000));

      await expectLater(running, completes);
    });
  });

  group('reset', () {
    test('goes back to the initial state and notifies', () async {
      choose();
      repo.stats = const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
      await vm.estimatePrice();
      notified = 0;

      vm.reset();

      expect(vm.selectedCategory, isNull);
      expect(vm.selectedCondition, isNull);
      expect(vm.hasEstimate, isFalse);
      expect(vm.suggestedPrice, isNull);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
      expect(notified, 1);
    });

    test('drops an estimate that was still on its way', () async {
      choose();
      repo.pending = Completer<PriceStats>();

      final running = vm.estimatePrice();
      vm.reset();
      repo.pending!.complete(const PriceStats(sampleSize: 9, p25: 1000, median: 2000, p75: 3000));
      await running;

      expect(vm.hasEstimate, isFalse);
      expect(vm.isLoading, isFalse);
    });
  });
}

/// Fails the first time, works the second.
class _FlakyEstimator extends PriceEstimatorUseCase {
  int calls = 0;

  @override
  Future<PriceEstimate> execute({
    required MaterialCategoryEnum category,
    required MaterialConditionEnum condition,
  }) async {
    if (calls++ == 0) throw StateError('first try fails');
    return heuristic(category: category, condition: condition);
  }
}
