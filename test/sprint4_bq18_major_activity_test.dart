import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/core/isolates/seller_profile_aggregator.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/dto/major_activity_model.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/seller_profile_entity.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/repositories/impl/major_activity_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/seller_profile_repository.dart';
import 'package:flutter_front_end/model/use_cases/seller_profile_use_cases.dart';
import 'package:flutter_front_end/view/screens/seller_profile_screen.dart';
import 'package:flutter_front_end/view_model/seller_profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _sampleBq18Json() => {
      'users_total': 42,
      'listings_total': 68,
      'inquiries_total': 95,
      'completed_exchanges_total': 29,
      'majors_active': 6,
      'faculties_active': 4,
      'by_major': [
        {
          'name': 'Systems Engineering',
          'faculty': 'Engineering',
          'users': 15,
          'active_sellers': 8,
          'listings': 24,
          'buyer_inquiries': 38,
          'completed_exchanges': 14,
          'conversion_rate': 0.5833,
        },
        {
          'name': 'Economics',
          'faculty': 'Economics',
          'users': 11,
          'active_sellers': 5,
          'listings': 16,
          'buyer_inquiries': 21,
          'completed_exchanges': 7,
          'conversion_rate': 0.4375,
        },
      ],
      'by_faculty': [
        {
          'name': 'Engineering',
          'users': 26,
          'active_sellers': 14,
          'listings': 42,
          'buyer_inquiries': 61,
          'completed_exchanges': 20,
          'conversion_rate': 0.4762,
        },
      ],
    };

class _StaticProfileRepo implements SellerProfileRepository {
  final SellerProfileData data;
  _StaticProfileRepo(this.data);

  @override
  Future<SellerProfileData> getSellerProfile(
    UserSummary seller, {
    List<MaterialEntity>? knownMaterials,
    bool forceRefresh = false,
  }) async =>
      data;

  @override
  void clearMemoryCache() {}
}

void main() {
  sqfliteFfiInit();

  group('BQ 18 · Major & Faculty Activity', () {
    test('parses /analytics/major-activity/ JSON, matches majors case-insensitively and computes rank', () {
      final insight = MajorActivityModel.fromJson(_sampleBq18Json());

      expect(insight.usersTotal, 42);
      expect(insight.listingsTotal, 68);
      expect(insight.inquiriesTotal, 95);
      expect(insight.completedExchangesTotal, 29);
      expect(insight.majorsActive, 6);

      final matched = insight.activityForMajor('  systems engineering ');
      expect(matched, isNotNull);
      expect(matched!.listings, 24);
      expect(matched.buyerInquiries, 38);
      expect(matched.completedExchanges, 14);
      expect(matched.conversionRatePercent, 58);
      expect(insight.rankOfMajor('Systems Engineering'), 1);
      expect(insight.rankOfMajor('Economics'), 2);
      expect(insight.activityForFaculty('engineering')?.completedExchanges, 20);
    });

    test('fetches live from /analytics/major-activity/ and falls back to SQLite ResponseCache offline', () async {
      final db = AppDatabase.withFactory(databaseFactoryFfi);
      final cache = ResponseCache(db);
      var offline = false;
      final client = MockClient((req) async {
        expect(req.url.path, '/analytics/major-activity/');
        if (offline) throw http.ClientException('offline');
        return http.Response.bytes(
          utf8.encode(jsonEncode(_sampleBq18Json())),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = MajorActivityRepositoryImpl(
        remote: AnalyticsRemoteDataSource(
          apiClient: ApiClient(baseUrl: 'https://analytics.test', client: client),
        ),
        cache: cache,
      );

      final live = await repo.getMajorActivity();
      expect(live.savedAt, isNull);
      expect(live.byMajor.first.name, 'Systems Engineering');

      offline = true;
      final cached = await repo.getMajorActivity();
      expect(cached.savedAt, isNotNull);
      expect(cached.listingsTotal, 68);
      expect(cached.activityForMajor('Systems Engineering')?.completedExchanges, 14);

      await db.close();
    });

    testWidgets('renders BQ 18 Campus Activity by Major card on SellerProfileScreen', (tester) async {
      const seller = UserSummary(
        id: 'seller-1',
        fullName: 'Camila Rojas',
        major: 'Systems Engineering',
        faculty: 'Engineering',
        rating: 4.9,
      );
      final summary = aggregateSellerProfileSync(
        const SellerProfileAggregationInput(
          reviews: [],
          sellerListings: [],
          fallbackRating: 4.9,
        ),
      );
      final data = SellerProfileData(
        seller: seller,
        summary: summary,
        majorActivity: MajorActivityModel.fromJson(_sampleBq18Json()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SellerProfileScreen(
            onClose: () {},
            onOpenMaterial: (_) {},
            createViewModel: () => SellerProfileViewModel(
              initialSeller: seller,
              getSellerProfile: GetSellerProfileUseCase(_StaticProfileRepo(data)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byKey(const Key('bq18-major-activity-card')), 200);
      expect(find.byKey(const Key('bq18-major-activity-card')), findsOneWidget);
      expect(find.text('Campus Activity by Major'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });
  });
}
