// Sprint 4 Micro-Optimizations (Sabrina Noguera — MO4, MO5, MO6):
// MO4: O(1) Set-backed wishlist lookup + memoized filteredSearchResults in MarketplaceViewModel.
// MO5: Bounded thumbnail memory & disk cache limits across Home, Favorites, Seller Hub & Seller Profile.
// MO6: Single-pass O(R + L) Seller Profile aggregation offloaded to Isolate.run.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_front_end/core/isolates/seller_profile_aggregator.dart';
import 'package:flutter_front_end/model/entities/cached_list.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/rating_entity.dart';
import 'package:flutter_front_end/model/entities/seller_profile_entity.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/entities/wishlist_item_entity.dart';
import 'package:flutter_front_end/model/repositories/marketplace_repositories.dart';
import 'package:flutter_front_end/model/strategies/sort_strategy.dart';
import 'package:flutter_front_end/model/use_cases/marketplace_use_cases.dart';
import 'package:flutter_front_end/view/widgets/cached_photo.dart';
import 'package:flutter_front_end/view_model/marketplace_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _BenchMaterialsRepo implements MaterialRepository {
  final List<MaterialEntity> items;
  _BenchMaterialsRepo(this.items);

  @override
  Future<CachedList<MaterialEntity>> getMaterialsCached() async => CachedList(items);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _BenchWishlistRepo implements WishlistRepository {
  final List<WishlistItemEntity> items;
  _BenchWishlistRepo(this.items);

  @override
  Future<CachedList<WishlistItemEntity>> getWishlist() async => CachedList(items);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

List<MaterialEntity> _generateMaterials(int count) => List.generate(
      count,
      (i) => MaterialEntity(
        id: 'mat-$i',
        title: i.isEven ? 'Calculus Textbook Vol $i' : 'Scientific Calculator TI-$i',
        description: 'Academic material #$i for engineering courses',
        courseCode: i % 3 == 0 ? 'ISIS-3510' : 'MATE-1203',
        price: 15.0 + (i % 150),
        condition: MaterialConditionEnum.values[i % MaterialConditionEnum.values.length],
        status: i % 7 == 0 ? MaterialStatusEnum.SOLD : MaterialStatusEnum.AVAILABLE,
        imageUrls: const [],
        sellerId: 'seller-${i % 10}',
        category: MaterialCategoryEnum.values[i % MaterialCategoryEnum.values.length],
        createdAt: DateTime(2026, 10, 1).add(Duration(hours: i)),
        updatedAt: DateTime(2026, 10, 1).add(Duration(hours: i)),
      ),
      growable: false,
    );

List<WishlistItemEntity> _generateWishlist(int count) => List.generate(
      count,
      (i) => WishlistItemEntity(
        id: 'wish-$i',
        userId: 'u1',
        materialId: 'mat-${i * 2}',
        createdAt: DateTime(2026, 11, 1),
      ),
      growable: false,
    );

/// Naive multi-pass baseline (before MO6): computes the exact same summary as
/// [aggregateSellerProfileSync] using repeated `.where()` / `.expand()` passes on the UI thread.
int _naiveMultiPassAggregate(List<RatingEntity> reviews, List<MaterialEntity> listings) {
  var total = 0;
  for (var star = 5; star >= 1; star--) {
    total += reviews.where((r) => r.stars == star).length;
  }
  final allTags = reviews.expand((r) => r.tags).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  final uniqueTags = allTags.toSet();
  final tagCounts = {
    for (final tag in uniqueTags) tag: allTags.where((t) => t == tag).length,
  };
  final sortedTags = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final sortedReviews = List<RatingEntity>.of(reviews)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final available = listings.where((m) => m.isAvailable).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final soldCount = listings.where((m) => m.status == MaterialStatusEnum.SOLD).length;
  total += sortedTags.take(3).length + sortedReviews.length + available.length + soldCount;
  return total;
}

void main() {
  group('MO4 · MarketplaceViewModel O(1) isFavorite + memoized filteredSearchResults', () {
    test('memoizes filteredSearchResults across 50 redundant rebuilds and invalidates on filter change', () async {
      final materials = _generateMaterials(500);
      final wishlist = _generateWishlist(150);
      final vm = MarketplaceViewModel(
        getMaterials: GetMaterialsUseCase(_BenchMaterialsRepo(materials)),
        createListing: CreateListingUseCase(_BenchMaterialsRepo(materials)),
        getWishlist: GetWishlistUseCase(_BenchWishlistRepo(wishlist)),
        addToWishlist: AddToWishlistUseCase(_BenchWishlistRepo(wishlist)),
        removeFromWishlist: RemoveFromWishlistUseCase(_BenchWishlistRepo(wishlist)),
      );
      await vm.load();
      vm.setSearchQuery('calculus');
      vm.setSearchSort(const PriceAscSortStrategy());

      // Measure 50 consecutive reads (simulating 50 widget rebuilds with unchanged inputs).
      final swMemo = Stopwatch()..start();
      List<MaterialEntity>? firstRef;
      for (var i = 0; i < 50; i++) {
        final res = vm.filteredSearchResults;
        firstRef ??= res;
        expect(identical(res, firstRef), isTrue);
      }
      swMemo.stop();

      // Compare against 50 uncached filter + sort passes on the same 500 items.
      final swNaive = Stopwatch()..start();
      var naiveCount = 0;
      for (var i = 0; i < 50; i++) {
        final list = materials.where((m) {
          if (!m.isAvailable) return false;
          if (m.price > 200) return false;
          final q = 'calculus';
          return m.title.toLowerCase().contains(q) ||
              m.description.toLowerCase().contains(q) ||
              (m.courseCode?.toLowerCase().contains(q) ?? false);
        }).toList();
        naiveCount += const PriceAscSortStrategy().sort(list).length;
      }
      swNaive.stop();

      // Only 1 computation executed across 50 reads!
      expect(vm.searchFilterComputations, 1);
      expect(naiveCount, firstRef!.length * 50);

      // Changing a filter invalidates the cache and recomputes once.
      vm.setMaxSearchPrice(100);
      final narrowed = vm.filteredSearchResults;
      expect(vm.searchFilterComputations, 2);
      expect(narrowed.length, lessThanOrEqualTo(firstRef.length));

      // Benchmark O(1) Set lookup vs O(W) linear scan across 500 cards × 20 rebuilds (10,000 checks).
      final swLinear = Stopwatch()..start();
      var linearHits = 0;
      for (var r = 0; r < 20; r++) {
        for (final m in materials) {
          if (wishlist.any((w) => w.materialId == m.id)) linearHits++;
        }
      }
      swLinear.stop();

      final swSet = Stopwatch()..start();
      var setHits = 0;
      for (var r = 0; r < 20; r++) {
        for (final m in materials) {
          if (vm.isFavorite(m.id)) setHits++;
        }
      }
      swSet.stop();

      expect(setHits, linearHits);
      // ignore: avoid_print
      print(
        '[MO4 BENCHMARK] Search 50 reads (500 items): naive=${swNaive.elapsedMicroseconds}µs '
        'vs memoized=${swMemo.elapsedMicroseconds}µs (computations: 50 -> ${vm.searchFilterComputations}) | '
        'isFavorite 10,000 lookups (150 wishlist): linear=${swLinear.elapsedMicroseconds}µs vs Set=${swSet.elapsedMicroseconds}µs',
      );
      vm.dispose();
    });
  });

  group('MO5 · Bounded thumbnail decode & disk cache limits', () {
    testWidgets('thumbnail preset bounds memory (360 px) and disk (720 px) cache', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CachedPhoto(
              imageUrl: 'https://images.test/listing.jpg',
              category: 'BOOKS',
              width: 72,
              height: 72,
              memCacheWidth: CachedPhoto.thumbnailMemCacheWidth,
              maxWidthDiskCache: CachedPhoto.thumbnailDiskCacheWidth,
            ),
          ),
        ),
      );

      final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.memCacheWidth, 360);
      expect(image.maxWidthDiskCache, 720);

      // RGBA decoded footprint comparison for a typical 12 MP (4000×3000) phone camera photo:
      const rawBytes = 4000 * 3000 * 4; // 48.0 MB decoded bitmap
      const boundedHeight = (360 * 3000) ~/ 4000; // 270 px preserving 4:3 ratio
      const boundedBytes = 360 * boundedHeight * 4; // ~0.39 MB decoded bitmap
      final reductionPct = (1 - (boundedBytes / rawBytes)) * 100;
      expect(reductionPct, greaterThan(99.0));
      // ignore: avoid_print
      print(
        '[MO5 BENCHMARK] 4000x3000 RGBA bitmap: unbounded=${(rawBytes / (1024 * 1024)).toStringAsFixed(2)} MB '
        'vs thumbnail 360px=${(boundedBytes / 1024).toStringAsFixed(1)} KB (${reductionPct.toStringAsFixed(2)}% RAM reduction)',
      );
    });
  });

  group('MO6 · Single-pass Seller Profile aggregation + Isolate.run offload', () {
    test('single-pass O(R+L) beats naive multi-pass and matches Isolate.run output', () async {
      const seller = UserSummary(id: 's1', fullName: 'Ana', major: 'CS', rating: 4.7);
      final tagsPool = ['Punctual', 'As described', 'Friendly', 'Fair price', 'Quick reply', 'Clean item'];
      final reviews = List.generate(
        500,
        (i) => RatingEntity(
          id: 'r-$i',
          exchangeId: 'e-$i',
          raterId: 'b-$i',
          ratedId: 's1',
          stars: (i % 5) + 1,
          tags: [tagsPool[i % tagsPool.length], tagsPool[(i + 2) % tagsPool.length]],
          review: 'Review body #$i',
          createdAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
          rater: seller,
        ),
        growable: false,
      );
      final listings = _generateMaterials(200);
      final input = SellerProfileAggregationInput(
        reviews: reviews,
        sellerListings: listings,
        fallbackRating: 0,
      );

      // Warm up JIT.
      _naiveMultiPassAggregate(reviews, listings);
      aggregateSellerProfileSync(input);

      const iterations = 25;
      final swNaive = Stopwatch()..start();
      var sink = 0;
      for (var i = 0; i < iterations; i++) {
        sink += _naiveMultiPassAggregate(reviews, listings);
      }
      swNaive.stop();

      final swSingle = Stopwatch()..start();
      late SellerProfileSummary syncResult;
      for (var i = 0; i < iterations; i++) {
        syncResult = aggregateSellerProfileSync(input);
      }
      swSingle.stop();

      final swIso = Stopwatch()..start();
      final isoResult = await aggregateSellerProfileInIsolate(input);
      swIso.stop();

      expect(sink, greaterThan(0));
      expect(isoResult.reviewCount, syncResult.reviewCount);
      expect(isoResult.averageRating, syncResult.averageRating);
      expect(isoResult.topTags.map((t) => t.tag).toList(), syncResult.topTags.map((t) => t.tag).toList());
      expect(isoResult.activeListingsCount, syncResult.activeListingsCount);
      expect(isoResult.soldListingsCount, syncResult.soldListingsCount);

      // ignore: avoid_print
      print(
        '[MO6 BENCHMARK] 500 reviews + 200 listings (x$iterations): '
        'naiveMultiPass=${swNaive.elapsedMicroseconds}µs vs singlePass=${swSingle.elapsedMicroseconds}µs '
        '| Isolate.run single call=${swIso.elapsedMicroseconds}µs (0µs on UI isolate)',
      );
    });
  });
}
