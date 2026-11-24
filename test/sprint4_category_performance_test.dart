// BQ6 (GET /analytics/categories/): DTO, repository with the offline copy, ViewModel that reloads
// on reconnection, and the Seller Hub card.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/dto/category_performance_model.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/category_performance.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/category_performance_repository.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/category_performance_repository_impl.dart';
import 'package:flutter_front_end/model/use_cases/get_category_performance_use_case.dart';
import 'package:flutter_front_end/view/widgets/category_performance_card.dart';
import 'package:flutter_front_end/view_model/category_performance_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _answer = {
  'data': [
    {'category': 'BOOKS', 'total_listings': 12, 'completed_exchanges': 4},
    {'category': 'LAB_EQUIPMENT', 'total_listings': 5, 'completed_exchanges': 1},
    {'category': 'CALCULATORS', 'total_listings': 0, 'completed_exchanges': 0},
  ],
};

/// A repository answering [results] in order; an exception entry is thrown.
class _ScriptedRepository implements CategoryPerformanceRepository {
  final List<Object> results;
  int calls = 0;
  Completer<void>? gate;

  _ScriptedRepository(this.results);

  @override
  Future<CachedList<CategoryPerformance>> getCategoryPerformance() async {
    calls++;
    await gate?.future;
    final next = results.removeAt(0);
    if (next is Exception || next is Error) throw next;
    return next as CachedList<CategoryPerformance>;
  }
}

class _Network implements ConnectivityRepository {
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> watch() => controller.stream;
}

CachedList<CategoryPerformance> _fresh() => CachedList(CategoryPerformanceModel.listFromJson(_answer));

void main() {
  sqfliteFfiInit();

  group('CategoryPerformanceModel', () {
    test('maps /analytics/categories/ keeping the server order', () {
      final categories = CategoryPerformanceModel.listFromJson(_answer);

      expect(categories.map((c) => c.category), ['BOOKS', 'LAB_EQUIPMENT', 'CALCULATORS']);
      expect(categories.first.totalListings, 12);
      expect(categories.first.completedExchanges, 4);
      expect(categories.first.displayName, 'Books');
      expect(categories[1].displayName, 'Lab Equipment');
      expect(categories.first.completionRate, closeTo(1 / 3, 1e-9));
      expect(categories.last.completionRate, 0);
    });

    test('skips rows without a category, reads missing counts as 0, names unknown categories', () {
      final categories = CategoryPerformanceModel.listFromJson({
        'data': [
          {'total_listings': 3},
          {'category': 'SPORTS_GEAR'},
          'not a row',
        ],
      });

      expect(categories.single.displayName, 'Sports Gear');
      expect(categories.single.totalListings, 0);
    });

    test('an answer without data is an empty list, and the saved copy keeps the same shape', () {
      expect(CategoryPerformanceModel.listFromJson({'data': null}), isEmpty);
      expect(CategoryPerformanceModel.listFromJson('nonsense'), isEmpty);

      final again = CategoryPerformanceModel.listFromJson(
        CategoryPerformanceModel.toJson(CategoryPerformanceModel.listFromJson(_answer)),
      );
      expect(again.map((c) => c.totalListings), [12, 5, 0]);
    });
  });

  group('CategoryPerformanceRepositoryImpl: networkFirst with the offline copy', () {
    late AppDatabase db;
    late bool offline;
    late int statusCode;

    CategoryPerformanceRepositoryImpl repository() => CategoryPerformanceRepositoryImpl(
          remote: AnalyticsRemoteDataSource(
            apiClient: ApiClient(
              baseUrl: 'https://analytics.test',
              client: MockClient((request) async {
                expect(request.url.path, '/analytics/categories/');
                if (offline) throw http.ClientException('no network');
                return http.Response(jsonEncode(_answer), statusCode);
              }),
            ),
          ),
          cache: ResponseCache(db),
        );

    Future<CachedJson?> saved() =>
        ResponseCache(db).read(CategoryPerformanceRepositoryImpl.cacheOwner, CategoryPerformanceRepositoryImpl.cacheKey);

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      offline = false;
      statusCode = 200;
    });

    tearDown(() => db.close());

    test('online: fresh figures, saved under global / category_performance', () async {
      final result = await repository().getCategoryPerformance();

      expect(result.isSavedCopy, isFalse);
      expect(result.items, hasLength(3));
      expect(CategoryPerformanceRepositoryImpl.cacheOwner, 'global');
      expect(CategoryPerformanceRepositoryImpl.cacheKey, 'category_performance');
      expect(await saved(), isNotNull);
    });

    test('offline: the copy saved last time, with when it was saved (as after a restart)', () async {
      await repository().getCategoryPerformance();
      offline = true;

      final result = await repository().getCategoryPerformance();

      expect(result.isSavedCopy, isTrue);
      expect(result.savedAt, isNotNull);
      expect(result.items.first.category, 'BOOKS');
    });

    test('a 5xx also falls back to the saved copy', () async {
      await repository().getCategoryPerformance();
      statusCode = 503;

      final result = await repository().getCategoryPerformance();

      expect(result.isSavedCopy, isTrue);
    });

    test('only successful answers are saved', () async {
      statusCode = 500;

      await expectLater(repository().getCategoryPerformance(), throwsA(isA<DataException>()));
      expect(await saved(), isNull);
    });

    test('offline with nothing saved: NoConnectionException', () async {
      offline = true;

      await expectLater(repository().getCategoryPerformance(), throwsA(isA<NoConnectionException>()));
    });
  });

  group('CategoryPerformanceViewModel', () {
    test('loads once; force reloads keeping the figures on screen', () async {
      final repository = _ScriptedRepository([_fresh(), _fresh()]);
      final vm = CategoryPerformanceViewModel(getCategoryPerformance: GetCategoryPerformanceUseCase(repository));

      await vm.load();
      await vm.load();
      expect(repository.calls, 1);
      expect(vm.highestListings, 12);

      repository.gate = Completer();
      final reload = vm.load(force: true);
      expect(vm.isLoading, isTrue);
      expect(vm.categories, hasLength(3));
      repository.gate!.complete();
      await reload;
      expect(repository.calls, 2);
      vm.dispose();
    });

    test('an error with nothing to show sets error; a later failure keeps the figures', () async {
      final repository = _ScriptedRepository([const NoConnectionException(), _fresh(), const DataException('boom')]);
      final vm = CategoryPerformanceViewModel(getCategoryPerformance: GetCategoryPerformanceUseCase(repository));

      await vm.load();
      expect(vm.error, isNotNull);
      expect(vm.isLoading, isFalse);

      await vm.load(force: true);
      await vm.load(force: true);
      expect(vm.error, isNull);
      expect(vm.categories, hasLength(3));
      vm.dispose();
    });

    test('an unexpected error never leaves it loading', () async {
      final vm = CategoryPerformanceViewModel(
        getCategoryPerformance: GetCategoryPerformanceUseCase(_ScriptedRepository([StateError('bad')])),
      );

      await vm.load();

      expect(vm.isLoading, isFalse);
      expect(vm.error, contains('try again'));
      vm.dispose();
    });

    test('reloads by itself when the connection comes back', () async {
      final network = _Network();
      final saved = CachedList(_fresh().items, savedAt: DateTime(2026, 11, 20));
      final repository = _ScriptedRepository([saved, _fresh()]);
      final vm = CategoryPerformanceViewModel(
        getCategoryPerformance: GetCategoryPerformanceUseCase(repository),
        connectivity: network,
      );
      await vm.load();
      expect(vm.isSavedCopy, isTrue);

      network.controller.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.calls, 1);

      network.controller.add(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls, 2);
      expect(vm.isSavedCopy, isFalse);
      vm.dispose();
      await network.controller.close();
    });
  });

  group('CategoryPerformanceCard', () {
    Future<void> pump(WidgetTester tester, CategoryPerformanceViewModel vm) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CategoryPerformanceCard(viewModel: vm))),
      ));
    }

    testWidgets('shows loading, then a row per category with an accessible summary', (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _ScriptedRepository([_fresh()])..gate = Completer();
      final vm = CategoryPerformanceViewModel(getCategoryPerformance: GetCategoryPerformanceUseCase(repository));
      await pump(tester, vm);
      await tester.pump();
      expect(find.byKey(const Key('category-performance-loading')), findsOneWidget);

      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-performance-figures')), findsOneWidget);
      expect(find.text('12 listed · 4 swapped (33%)'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Books: 12 listings, 4 completed exchanges, 33 percent completed'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('category-performance-saved-copy')), findsNothing);
      vm.dispose();
      semantics.dispose();
    });

    testWidgets('marks the offline copy as possibly outdated', (tester) async {
      final saved = CachedList(_fresh().items, savedAt: DateTime.now().subtract(const Duration(hours: 2)));
      final vm = CategoryPerformanceViewModel(
        getCategoryPerformance: GetCategoryPerformanceUseCase(_ScriptedRepository([saved])),
      );
      await pump(tester, vm);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-performance-saved-copy')), findsOneWidget);
      expect(find.text('Offline copy · saved 2h ago, may be outdated'), findsOneWidget);
      vm.dispose();
    });

    testWidgets('empty figures say so', (tester) async {
      final vm = CategoryPerformanceViewModel(
        getCategoryPerformance: GetCategoryPerformanceUseCase(_ScriptedRepository([const CachedList<CategoryPerformance>([])])),
      );
      await pump(tester, vm);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-performance-empty')), findsOneWidget);
      vm.dispose();
    });

    testWidgets('an error offers "Try again", which loads the figures', (tester) async {
      final repository = _ScriptedRepository([const NoConnectionException(), _fresh()]);
      final vm = CategoryPerformanceViewModel(getCategoryPerformance: GetCategoryPerformanceUseCase(repository));
      await pump(tester, vm);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-performance-error')), findsOneWidget);

      await tester.tap(find.byKey(const Key('category-performance-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-performance-figures')), findsOneWidget);
      expect(repository.calls, 2);
      vm.dispose();
    });
  });
}
