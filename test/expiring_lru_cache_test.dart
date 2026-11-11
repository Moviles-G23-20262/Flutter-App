// ExpiringLruCache (size limit + time limit) and its use in PriceStatsRepositoryImpl.
import 'dart:convert';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/expiring_lru_cache.dart';
import 'package:flutter_front_end/model/repositories/impl/price_stats_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ExpiringLruCache', () {
    late DateTime now;
    late ExpiringLruCache<String, int> cache;

    setUp(() {
      now = DateTime(2026, 11, 11, 10);
      cache = ExpiringLruCache(maxSize: 2, ttl: const Duration(minutes: 10), now: () => now);
    });

    test('returns what was stored, and null for an unknown key', () {
      cache.put('a', 1);

      expect(cache.get('a'), 1);
      expect(cache.get('b'), isNull);
    });

    test('an entry is valid until its ttl is over, then it is gone and forgotten', () {
      cache.put('a', 1);

      now = now.add(const Duration(minutes: 9, seconds: 59));
      expect(cache.get('a'), 1);

      now = now.add(const Duration(seconds: 2)); // 10 min 1 s after it was stored
      expect(cache.get('a'), isNull);
      expect(cache.length, 0);
    });

    test('the ttl starts again when a key is stored again', () {
      cache.put('a', 1);
      now = now.add(const Duration(minutes: 8));
      cache.put('a', 2);

      now = now.add(const Duration(minutes: 8)); // 16 min after the first put, 8 after the second
      expect(cache.get('a'), 2);
    });

    test('when full, the least recently used entry is dropped', () {
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
      expect(cache.length, 2);
    });

    test('reading an entry makes it the most recently used one', () {
      cache.put('a', 1);
      cache.put('b', 2);
      cache.get('a'); // b is now the oldest
      cache.put('c', 3);

      expect(cache.get('b'), isNull);
      expect(cache.get('a'), 1);
      expect(cache.keys.toList(), ['c', 'a']);
    });

    test('remove and clear', () {
      cache.put('a', 1);
      cache.put('b', 2);

      expect(cache.remove('a'), 1);
      expect(cache.get('a'), isNull);
      cache.clear();
      expect(cache.length, 0);
    });

    test('a ttl of zero is not allowed', () {
      expect(() => ExpiringLruCache<String, int>(maxSize: 1, ttl: Duration.zero), throwsA(isA<AssertionError>()));
    });
  });

  group('PriceStatsRepositoryImpl cache', () {
    late DateTime now;
    late int requests;
    late bool offline;

    PriceStatsRepositoryImpl repository({int size = PriceStatsRepositoryImpl.cacheSize}) => PriceStatsRepositoryImpl(
          AnalyticsRemoteDataSource(
            apiClient: ApiClient(
              baseUrl: 'https://analytics.test',
              client: MockClient((request) async {
                requests++;
                if (offline) throw http.ClientException('no network');
                return http.Response(
                  jsonEncode({'sample_size': 8, 'p25': 10000, 'median': 20000, 'p75': 30000}),
                  200,
                );
              }),
            ),
          ),
          cache: ExpiringLruCache(maxSize: size, ttl: PriceStatsRepositoryImpl.cacheTtl, now: () => now),
        );

    setUp(() {
      now = DateTime(2026, 11, 11, 10);
      requests = 0;
      offline = false;
    });

    test('asking again for the same category and condition does not repeat the request', () async {
      final repo = repository();

      final first = await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');
      final second = await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');

      expect(requests, 1);
      expect(second.median, first.median);
    });

    test('another combination is another request', () async {
      final repo = repository();

      await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');
      await repo.getPriceStats(category: 'BOOKS', condition: 'NEW');

      expect(requests, 2);
    });

    test('after the ttl the server is asked again', () async {
      final repo = repository();
      await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');

      now = now.add(PriceStatsRepositoryImpl.cacheTtl + const Duration(seconds: 1));
      await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');

      expect(requests, 2);
    });

    test('a combination pushed out by the size limit is asked again', () async {
      final repo = repository(size: 1);
      await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');
      await repo.getPriceStats(category: 'BOOKS', condition: 'NEW');

      await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');

      expect(requests, 3);
    });

    test('a failure is not cached: the next ask tries the network again', () async {
      final repo = repository();
      offline = true;
      await expectLater(
        repo.getPriceStats(category: 'BOOKS', condition: 'GOOD'),
        throwsA(isA<NetworkException>()),
      );

      offline = false;
      final stats = await repo.getPriceStats(category: 'BOOKS', condition: 'GOOD');

      expect(stats.sampleSize, 8);
      expect(requests, 2);
    });
  });
}
