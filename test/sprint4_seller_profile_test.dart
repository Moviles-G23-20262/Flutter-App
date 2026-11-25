import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/core/cache/lru_cache.dart';
import 'package:flutter_front_end/core/isolates/seller_profile_aggregator.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/data_sources/local/seller_profile_store.dart';
import 'package:flutter_front_end/model/data_sources/marketplace_remote_data_source.dart';
import 'package:flutter_front_end/model/dto/seller_reputation_model.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/rating_entity.dart';
import 'package:flutter_front_end/model/entities/seller_profile_entity.dart';
import 'package:flutter_front_end/model/entities/seller_reputation.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/seller_profile_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/impl/seller_reputation_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/seller_profile_repository.dart';
import 'package:flutter_front_end/model/repositories/seller_reputation_repository.dart';
import 'package:flutter_front_end/model/use_cases/seller_profile_use_cases.dart';
import 'package:flutter_front_end/view/screens/seller_profile_screen.dart';
import 'package:flutter_front_end/view_model/seller_profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Test fixtures ─────────────────────────────────────────────────────────────

const _seller = UserSummary(
  id: 'seller-1',
  fullName: 'Camila Rojas',
  major: 'Systems Engineering',
  faculty: 'Engineering',
  rating: 4.8,
);

const _buyer = UserSummary(
  id: 'buyer-1',
  fullName: 'Mateo Diaz',
  major: 'Mathematics',
  rating: 4.9,
);

MaterialEntity _listing(
  String id, {
  String sellerId = 'seller-1',
  MaterialStatusEnum status = MaterialStatusEnum.AVAILABLE,
  double price = 45000,
  String title = 'Linear Algebra Book',
}) =>
    MaterialEntity(
      id: id,
      title: title,
      description: 'Clean copy with no highlights',
      courseCode: 'MATE-1105',
      price: price,
      condition: MaterialConditionEnum.LIKE_NEW,
      status: status,
      imageUrls: const [],
      sellerId: sellerId,
      seller: _seller,
      category: MaterialCategoryEnum.BOOKS,
      createdAt: DateTime(2026, 11, 10),
      updatedAt: DateTime(2026, 11, 11),
    );

RatingEntity _rating(
  String id, {
  int stars = 5,
  List<String> tags = const ['Punctual', 'As described'],
  String? review = 'Great seller, met on time at ML building.',
  DateTime? createdAt,
}) =>
    RatingEntity(
      id: id,
      exchangeId: 'ex-$id',
      raterId: _buyer.id,
      ratedId: _seller.id,
      stars: stars,
      tags: tags,
      review: review,
      createdAt: createdAt ?? DateTime(2026, 11, 12, 10),
      rater: _buyer,
    );

Map<String, dynamic> _sampleBq17Json() => {
      'listings_total': 120,
      'sellers_with_reviews': 38,
      'by_stars': [
        {
          'group': 'no_reviews',
          'label': 'No reviews yet',
          'sellers': 20,
          'listings': 40,
          'contacted': 16,
          'contact_rate': 0.40,
          'buyers_per_listing': 0.6,
          'sold': 10,
          'sale_rate': 0.25,
          'median_days_to_sell': 6.5,
        },
        {
          'group': '4_5_and_up',
          'label': '4.5+ stars',
          'sellers': 18,
          'listings': 50,
          'contacted': 40,
          'contact_rate': 0.80,
          'buyers_per_listing': 2.1,
          'sold': 34,
          'sale_rate': 0.68,
          'median_days_to_sell': 2.4,
        },
      ],
      'by_review_count': [
        {
          'group': '3_5',
          'label': '3–5 reviews',
          'sellers': 12,
          'listings': 35,
          'contacted': 26,
          'contact_rate': 0.74,
          'buyers_per_listing': 1.8,
          'sold': 22,
          'sale_rate': 0.63,
          'median_days_to_sell': 2.9,
        },
      ],
    };

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeRemote implements MarketplaceRemoteDataSource {
  bool offline = false;
  int ratingsCalls = 0;
  int materialsCalls = 0;
  List<RatingEntity> ratings = [];
  List<MaterialEntity> materials = [];

  @override
  Future<List<RatingEntity>> getRatingsForUser(String userId) async {
    ratingsCalls++;
    if (offline) throw const NetworkException('offline');
    return ratings;
  }

  @override
  Future<List<MaterialEntity>> getMaterials() async {
    materialsCalls++;
    if (offline) throw const NetworkException('offline');
    return materials;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeReputationRepo implements SellerReputationRepository {
  bool fail = false;
  int calls = 0;
  SellerReputationInsight insight = SellerReputationModel.fromJson(_sampleBq17Json());

  @override
  Future<SellerReputationInsight> getSellerReputation() async {
    calls++;
    if (fail) throw const NoConnectionException();
    return insight;
  }
}

class _FakeConnectivity implements ConnectivityRepository {
  final StreamController<bool> controller = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => controller.stream;

  void emit(bool value) {
    online = value;
    controller.add(value);
  }

  void close() => controller.close();
}

class _StaticProfileRepo implements SellerProfileRepository {
  Future<SellerProfileData> Function(UserSummary, bool forceRefresh) handler;
  _StaticProfileRepo(this.handler);

  @override
  Future<SellerProfileData> getSellerProfile(
    UserSummary seller, {
    List<MaterialEntity>? knownMaterials,
    bool forceRefresh = false,
  }) =>
      handler(seller, forceRefresh);

  @override
  void clearMemoryCache() {}
}

void main() {
  sqfliteFfiInit();

  group('Local Storage · AppDatabase v3 → v4 migration & SellerProfileStore (30-seller cap)', () {
    test('migrates v3 database to v4, creates seller_profiles and preserves existing rows', () async {
      // Simulate an existing phone on schema version 3.
      final tempDir = Directory.systemTemp.createTempSync('db_v3_v4_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final tempPath = '${tempDir.path}/campus_swap.db';
      final v3Db = await databaseFactoryFfi.openDatabase(
        tempPath,
        options: OpenDatabaseOptions(
          version: 3,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE cached_responses (
                owner_id TEXT NOT NULL,
                cache_key TEXT NOT NULL,
                body TEXT NOT NULL,
                saved_at INTEGER NOT NULL,
                PRIMARY KEY (owner_id, cache_key)
              )''');
            await db.execute('''
              CREATE TABLE pending_messages (
                id TEXT PRIMARY KEY,
                owner_id TEXT NOT NULL,
                chat_room_id TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                last_error TEXT
              )''');
            await db.execute('''
              CREATE TABLE pending_listings (
                id TEXT PRIMARY KEY,
                owner_id TEXT NOT NULL,
                payload TEXT NOT NULL,
                photo_paths TEXT NOT NULL,
                uploaded_urls TEXT NOT NULL DEFAULT '[]',
                created_at INTEGER NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                last_error TEXT
              )''');
            await db.execute('''
              CREATE TABLE pending_actions (
                id TEXT PRIMARY KEY,
                owner_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                group_id TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                last_error TEXT
              )''');
            await db.insert('cached_responses', {
              'owner_id': 'u1',
              'cache_key': 'home',
              'body': '[]',
              'saved_at': 12345,
            });
          },
        ),
      );
      await v3Db.close();

      // Now open with AppDatabase (version 4) — triggers onUpgrade(3 -> 4).
      final upgraded = AppDatabase.withFactory(databaseFactoryFfi, path: tempPath);
      final db = await upgraded.database;
      final preserved = await db.query('cached_responses');
      expect(preserved, hasLength(1));
      expect(preserved.first['cache_key'], 'home');

      final store = SellerProfileStore(upgraded);
      await store.save('seller-1', {'ok': true});
      final read = await store.read('seller-1');
      expect(read?.body['ok'], isTrue);
      await upgraded.close();
    });

    test('prunes seller_profiles to the 30 most recently visited sellers in one transaction', () async {
      final db = AppDatabase.withFactory(databaseFactoryFfi);
      var clock = DateTime(2026, 11, 20, 12, 0);
      final store = SellerProfileStore(db, clock: () => clock);

      for (var i = 1; i <= 35; i++) {
        clock = clock.add(const Duration(seconds: 1));
        await store.save('seller-$i', {'index': i});
      }

      expect(await store.count(), SellerProfileStore.maxCachedSellers);
      // The oldest 5 (seller-1..seller-5) were evicted; seller-6..seller-35 remain.
      expect(await store.read('seller-1'), isNull);
      expect(await store.read('seller-5'), isNull);
      expect((await store.read('seller-6'))?.body['index'], 6);
      expect((await store.read('seller-35'))?.body['index'], 35);
      await db.close();
    });
  });

  group('Caching · LruCache (cap 20, 2-min TTL) & SellerProfileRepositoryImpl', () {
    test('LruCache evicts least recently used and expires entries after TTL', () {
      var now = DateTime(2026, 11, 20, 10, 0);
      final cache = LruCache<String, int>(
        maxEntries: 2,
        ttl: const Duration(minutes: 2),
        clock: () => now,
      );

      cache.put('a', 1);
      cache.put('b', 2);
      expect(cache.get('a'), 1); // 'a' becomes MRU; 'b' is LRU
      cache.put('c', 3); // evicts 'b'
      expect(cache.get('b'), isNull);
      expect(cache.get('a'), 1);

      now = now.add(const Duration(minutes: 2, seconds: 1));
      expect(cache.get('a'), isNull); // expired past 2-min TTL
    });

    test('serves repeat visits from L1 memory cache (0 network calls); pull-to-refresh bypasses L1', () async {
      final db = AppDatabase.withFactory(databaseFactoryFfi);
      final remote = _FakeRemote()
        ..ratings = [_rating('r1', stars: 5), _rating('r2', stars: 4)]
        ..materials = [_listing('m1'), _listing('m2', status: MaterialStatusEnum.SOLD)];
      final reputation = _FakeReputationRepo();
      var now = DateTime(2026, 11, 20, 12, 0);
      final repo = SellerProfileRepositoryImpl(
        remote: remote,
        store: SellerProfileStore(db, clock: () => now),
        reputationRepository: reputation,
        clock: () => now,
      );

      // 1st open: hits network + persists to SQLite + populates L1 cache.
      final first = await repo.getSellerProfile(_seller);
      expect(first.fromMemoryCache, isFalse);
      expect(first.isOfflineCopy, isFalse);
      expect(first.summary.reviewCount, 2);
      expect(first.summary.averageRating, 4.5);
      expect(first.summary.activeListingsCount, 1);
      expect(first.summary.soldListingsCount, 1);
      expect(remote.ratingsCalls, 1);
      expect(remote.materialsCalls, 1);

      // 2nd open within 2 minutes: served directly from L1 LRU cache (0 network calls).
      final second = await repo.getSellerProfile(_seller);
      expect(second.fromMemoryCache, isTrue);
      expect(remote.ratingsCalls, 1);
      expect(repo.memoryCacheHits, 1);

      // Pull-to-refresh bypasses L1 cache.
      final refreshed = await repo.getSellerProfile(_seller, forceRefresh: true);
      expect(refreshed.fromMemoryCache, isFalse);
      expect(remote.ratingsCalls, 2);

      // Past 2-min TTL: expires L1 and falls back to L2 SQLite when offline.
      now = now.add(const Duration(minutes: 3));
      remote.offline = true;
      final offlineCopy = await repo.getSellerProfile(_seller);
      expect(offlineCopy.isOfflineCopy, isTrue);
      expect(offlineCopy.savedAt, isNotNull);
      expect(offlineCopy.summary.reviewCount, 2);

      // Never-opened seller while offline throws NoConnectionException.
      const unseen = UserSummary(id: 'seller-999', fullName: 'Unseen User', major: 'Physics', rating: 0);
      expect(() => repo.getSellerProfile(unseen), throwsA(isA<NoConnectionException>()));

      await db.close();
    });
  });

  group('Multi-threading · Isolate.run aggregation & BQ 17 reputation parsing', () {
    test('aggregates star distribution, top 3 tags, and listing counts accurately in Isolate.run', () async {
      final summary = await aggregateSellerProfileInIsolate(
        SellerProfileAggregationInput(
          reviews: [
            _rating('1', stars: 5, tags: const ['Punctual', 'Friendly'], createdAt: DateTime(2026, 11, 1)),
            _rating('2', stars: 5, tags: const ['Punctual', 'As described'], createdAt: DateTime(2026, 11, 5)),
            _rating('3', stars: 4, tags: const ['Punctual', 'Fair price', 'Friendly'], createdAt: DateTime(2026, 11, 3)),
            _rating('4', stars: 3, tags: const ['As described'], createdAt: DateTime(2026, 11, 2)),
          ],
          sellerListings: [
            _listing('a1', status: MaterialStatusEnum.AVAILABLE),
            _listing('a2', status: MaterialStatusEnum.AVAILABLE),
            _listing('s1', status: MaterialStatusEnum.SOLD),
          ],
          fallbackRating: 0,
        ),
      );

      expect(summary.reviewCount, 4);
      expect(summary.averageRating, 4.25);
      expect(summary.starDistribution.map((b) => '${b.stars}:${b.count}').toList(), [
        '5:2',
        '4:1',
        '3:1',
        '2:0',
        '1:0',
      ]);
      expect(summary.topTags.map((t) => '${t.tag}:${t.count}').toList(), [
        'Punctual:3',
        'As described:2',
        'Friendly:2',
      ]);
      expect(summary.activeListingsCount, 2);
      expect(summary.soldListingsCount, 1);
      expect(summary.totalListingsCount, 3);
      // Newest first.
      expect(summary.reviews.first.id, '2');
      expect(summary.reviews.last.id, '1');
    });

    test('BQ 17 parses /analytics/seller-reputation/ and falls back to ResponseCache offline', () async {
      final db = AppDatabase.withFactory(databaseFactoryFfi);
      final responseCache = ResponseCache(db);
      var failNetwork = false;
      final client = MockClient((req) async {
        expect(req.url.path, '/analytics/seller-reputation/');
        if (failNetwork) throw http.ClientException('offline');
        return http.Response.bytes(
          utf8.encode(jsonEncode(_sampleBq17Json())),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repo = SellerReputationRepositoryImpl(
        remote: AnalyticsRemoteDataSource(
          apiClient: ApiClient(baseUrl: 'https://analytics.test', client: client),
        ),
        cache: responseCache,
      );

      final live = await repo.getSellerReputation();
      expect(live.savedAt, isNull);
      expect(live.listingsTotal, 120);
      final tier = live.starTierFor(averageRating: 4.8, reviewCount: 4);
      expect(tier?.label, '4.5+ stars');
      expect(tier?.saleRatePercent, 68);
      expect(tier?.medianDaysToSell, 2.4);

      failNetwork = true;
      final cached = await repo.getSellerReputation();
      expect(cached.savedAt, isNotNull);
      expect(cached.listingsTotal, 120);

      await db.close();
    });
  });

  group('Eventual Connectivity · SellerProfileViewModel auto-reload & SellerProfileScreen UI', () {
    test('automatically reloads when connectivity returns after showing an offline copy', () async {
      final connectivity = _FakeConnectivity();
      var calls = 0;
      final repo = _StaticProfileRepo((seller, forceRefresh) async {
        calls++;
        final summary = aggregateSellerProfileSync(
          SellerProfileAggregationInput(
            reviews: [_rating('r1')],
            sellerListings: [_listing('m1')],
            fallbackRating: seller.rating,
          ),
        );
        return SellerProfileData(
          seller: seller,
          summary: summary,
          savedAt: calls == 1 ? DateTime(2026, 11, 20, 8, 0) : null,
        );
      });

      final vm = SellerProfileViewModel(
        initialSeller: _seller,
        getSellerProfile: GetSellerProfileUseCase(repo),
        connectivity: connectivity,
      );

      connectivity.emit(false);
      await vm.load();
      expect(vm.isShowingOfflineCopy, isTrue);
      expect(calls, 1);

      // Reconnect triggers auto-reload with fresh data.
      connectivity.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls, 2);
      expect(vm.isShowingOfflineCopy, isFalse);

      vm.dispose();
      connectivity.close();
    });

    testWidgets('renders header, Buyers say, star bars, BQ 17 benchmark, listings, and reviews', (tester) async {
      MaterialEntity? openedListing;
      final listing = _listing('m1', title: 'Calculus 8th Edition');
      final summary = aggregateSellerProfileSync(
        SellerProfileAggregationInput(
          reviews: [_rating('r1', stars: 5, tags: const ['Punctual', 'Great condition'])],
          sellerListings: [listing],
          fallbackRating: _seller.rating,
        ),
      );
      final data = SellerProfileData(
        seller: _seller,
        summary: summary,
        reputation: SellerReputationModel.fromJson(_sampleBq17Json()),
        savedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final repo = _StaticProfileRepo((_, _) async => data);

      await tester.pumpWidget(
        MaterialApp(
          home: SellerProfileScreen(
            onClose: () {},
            onOpenMaterial: (m) => openedListing = m,
            createViewModel: () => SellerProfileViewModel(
              initialSeller: _seller,
              getSellerProfile: GetSellerProfileUseCase(repo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Camila Rojas'), findsOneWidget);
      expect(find.text('Buyers say'), findsOneWidget);
      expect(find.textContaining('PUNCTUAL', findRichText: true), findsWidgets);
      expect(find.text('Rating Breakdown'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('bq17-reputation-card')), 200);
      expect(find.byKey(const Key('bq17-reputation-card')), findsOneWidget);
      expect(find.byKey(const Key('saved-copy-banner-text')), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Calculus 8th Edition'), 200);
      expect(find.text('Calculus 8th Edition'), findsOneWidget);
      await tester.tap(find.text('Calculus 8th Edition'));
      expect(openedListing?.id, 'm1');
    });

    testWidgets('renders clean offline empty state with Retry and Go back when seller never cached', (tester) async {
      var backedOut = false;
      final repo = _StaticProfileRepo((_, _) async => throw const NoConnectionException());

      await tester.pumpWidget(
        MaterialApp(
          home: SellerProfileScreen(
            onClose: () => backedOut = true,
            onOpenMaterial: (_) {},
            createViewModel: () => SellerProfileViewModel(
              initialSeller: _seller,
              getSellerProfile: GetSellerProfileUseCase(repo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      expect(backedOut, isTrue);
    });
  });
}
