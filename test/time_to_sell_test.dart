import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/dto/time_to_sell_model.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/enums.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/new_listing_data.dart';
import 'package:flutter_front_end/model/entities/price_stats.dart';
import 'package:flutter_front_end/model/entities/time_to_sell.dart';
import 'package:flutter_front_end/model/entities/wishlist_item_entity.dart';
import 'package:flutter_front_end/model/repositories/impl/time_to_sell_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/model/repositories/time_to_sell_repository.dart';
import 'package:flutter_front_end/model/use_cases/get_time_to_sell_use_case.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/view_model/marketplace_view_model.dart';
import 'package:flutter_front_end/view_model/smart_listing_view_model.dart';

class _FakePriceStatsRepository implements PriceStatsRepository {
  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) async {
    return const PriceStats(sampleSize: 10, p25: 20000, median: 35000, p75: 50000);
  }
}

class _FakeMaterialsRepository implements MaterialRepository {
  @override
  Future<List<MaterialEntity>> getMaterials() async => [];
  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() async =>
      const CachedList([]);
  @override
  Future<MaterialEntity> createListing(NewListingData data) => throw UnimplementedError();
}

class _FakeWishlistRepository implements WishlistRepository {
  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() async =>
      const CachedList([]);
  @override
  Future<WishlistItemEntity> add(String materialId) => throw UnimplementedError();
  @override
  Future<void> remove(String wishlistItemId) => throw UnimplementedError();
}

class _FakeTimeToSellRepository implements TimeToSellRepository {
  final TimeToSellInsight result;
  _FakeTimeToSellRepository(this.result);

  @override
  Future<TimeToSellInsight> getTimeToSell() async => result;
}

void main() {
  sqfliteFfiInit();

  group('BQ11 - TimeToSellModel & TimeToSellInsight', () {
    test('parses analytics JSON payload correctly', () {
      final json = {
        'sold_listings': 5,
        'skipped': 1,
        'days_to_sell': {
          'mean': 4.2,
          'median': 3.0,
          'p75': 6.5,
          'min': 0.5,
          'max': 12.0,
        },
        'histogram': [
          {'bucket': 'Under 1 day', 'sold': 1},
          {'bucket': '1-3 days', 'sold': 2},
          {'bucket': '3-7 days', 'sold': 1},
          {'bucket': '1-2 weeks', 'sold': 1},
        ],
        'by_category': [
          {'category': 'BOOKS', 'sold': 3, 'mean_days': 4.0, 'median_days': 3.5},
          {'category': 'CALCULATORS', 'sold': 2, 'mean_days': 2.5, 'median_days': 2.0},
        ],
      };

      final model = TimeToSellModel.fromJson(json);

      expect(model.hasData, isTrue);
      expect(model.soldListings, 5);
      expect(model.skipped, 1);
      expect(model.meanDays, 4.2);
      expect(model.medianDays, 3.0);
      expect(model.p75Days, 6.5);
      expect(model.minDays, 0.5);
      expect(model.maxDays, 12.0);

      expect(model.daysForCategory('BOOKS'), 4.0);
      expect(model.daysForCategory('books'), 4.0);
      expect(model.daysForCategory('CALCULATORS'), 2.5);
      expect(model.daysForCategory('OTHER'), 4.2); // falls back to overall mean
    });

    test('handles empty response gracefully', () {
      final model = TimeToSellModel.fromJson({});

      expect(model.hasData, isFalse);
      expect(model.soldListings, 0);
      expect(model.meanDays, 0.0);
      expect(model.daysForCategory('BOOKS'), isNull);
    });

    test('serializes to JSON and round-trips correctly', () {
      const original = TimeToSellModel(
        soldListings: 2,
        meanDays: 3.5,
        medianDays: 3.0,
        categoryMeans: {'BOOKS': 3.5},
        categoryMedians: {'BOOKS': 3.0},
      );

      final json = original.toJson();
      final restored = TimeToSellModel.fromJson(json);

      expect(restored.soldListings, 2);
      expect(restored.meanDays, 3.5);
      expect(restored.daysForCategory('BOOKS'), 3.5);
    });
  });

  group('BQ11 - TimeToSellRepositoryImpl with Cache', () {
    test('falls back to ResponseCache when remote fails', () async {
      final db = AppDatabase.withFactory(databaseFactoryFfi);
      final cache = ResponseCache(db);

      // Pre-populate cache
      const cachedInsight = TimeToSellModel(
        soldListings: 4,
        meanDays: 2.8,
        medianDays: 2.5,
        categoryMeans: {'CALCULATORS': 2.0},
      );
      await cache.save('global', 'time_to_sell_bq11', cachedInsight.toJson());

      // Create repository with remote that throws
      final repo = TimeToSellRepositoryImpl(
        remote: _FailingRemoteDataSource(),
        cache: cache,
      );

      final result = await repo.getTimeToSell();
      expect(result.hasData, isTrue);
      expect(result.soldListings, 4);
      expect(result.meanDays, 2.8);
      expect(result.daysForCategory('CALCULATORS'), 2.0);
    });
  });

  group('BQ11 - MarketplaceViewModel integration', () {
    test('loads BQ11 timeToSell on load() and resets on clear()', () async {
      const sampleInsight = TimeToSellInsight(
        soldListings: 10,
        meanDays: 3.1,
        medianDays: 2.5,
      );

      final vm = MarketplaceViewModel(
        getMaterials: GetMaterialsUseCase(_FakeMaterialsRepository()),
        createListing: CreateListingUseCase(_FakeMaterialsRepository()),
        getWishlist: GetWishlistUseCase(_FakeWishlistRepository()),
        addToWishlist: AddToWishlistUseCase(_FakeWishlistRepository()),
        removeFromWishlist: RemoveFromWishlistUseCase(_FakeWishlistRepository()),
        getTimeToSell: GetTimeToSellUseCase(_FakeTimeToSellRepository(sampleInsight)),
      );

      expect(vm.timeToSell, isNull);

      await vm.load();

      expect(vm.timeToSell, isNotNull);
      expect(vm.timeToSell!.soldListings, 10);
      expect(vm.timeToSell!.meanDays, 3.1);

      vm.clear();

      expect(vm.timeToSell, isNull);
    });
  });

  group('BQ11 - SmartListingViewModel integration', () {
    test('estimatePrice sets estimatedDaysToSell for the chosen category', () async {
      const insight = TimeToSellInsight(
        soldListings: 8,
        meanDays: 5.0,
        medianDays: 4.0,
        categoryMeans: {'BOOKS': 3.2, 'CALCULATORS': 1.8},
      );

      final vm = SmartListingViewModel(
        estimator: PriceEstimatorUseCase(repository: _FakePriceStatsRepository()),
        getTimeToSell: GetTimeToSellUseCase(_FakeTimeToSellRepository(insight)),
      );

      vm.setCategory(MaterialCategoryEnum.BOOKS.name);
      vm.setCondition(MaterialConditionEnum.GOOD.name);

      expect(vm.estimatedDaysToSell, isNull);

      await vm.estimatePrice();

      expect(vm.estimatedDaysToSell, 3.2);
    });
  });
}

class _FailingRemoteDataSource extends AnalyticsRemoteDataSource {
  _FailingRemoteDataSource() : super(apiClient: ApiClient(baseUrl: 'http://localhost', client: http.Client()));

  @override
  Future<TimeToSellModel> getTimeToSell() async {
    throw Exception('Connection failed');
  }
}
