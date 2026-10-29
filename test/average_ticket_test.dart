// Average ticket (GET /analytics/average-ticket/): DTO, repository with offline copy, ViewModel
// and the Seller Hub card.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/analytics_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/dto/average_ticket_model.dart';
import 'package:flutter_front_end/model/entities/average_ticket.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/average_ticket_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/average_ticket_repository_impl.dart';
import 'package:flutter_front_end/model/use_cases/get_average_ticket_use_case.dart';
import 'package:flutter_front_end/view/widgets/average_ticket_card.dart';
import 'package:flutter_front_end/view/widgets/formatters.dart';
import 'package:flutter_front_end/view_model/average_ticket_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _answer = {
  'globalAverage': 45000,
  'byCondition': {'NEW': 60000, 'USED': 1, 'GOOD': 30000},
};

/// A repository answering [results] in order; a [DataException] entry is thrown.
class _ScriptedRepository implements AverageTicketRepository {
  final List<Object> results;
  int calls = 0;
  Completer<void>? gate;

  _ScriptedRepository(this.results);

  @override
  Future<AverageTicket> getAverageTicket() async {
    calls++;
    await gate?.future;
    final next = results.removeAt(0);
    if (next is DataException) throw next;
    return next as AverageTicket;
  }
}

void main() {
  sqfliteFfiInit();

  group('AverageTicketModel', () {
    test('parses the endpoint answer, best condition first, skipping unknown conditions', () {
      final ticket = AverageTicketModel.fromJson(_answer);

      expect(ticket.globalAverage, 45000);
      expect(ticket.byCondition, {MaterialConditionEnum.NEW: 60000, MaterialConditionEnum.GOOD: 30000});
      expect(ticket.byCondition.keys.first, MaterialConditionEnum.NEW);
      expect(ticket.highestByCondition, 60000);
    });

    test('no completed sales yet means no data', () {
      final ticket = AverageTicketModel.fromJson({'globalAverage': null, 'byCondition': {}});

      expect(ticket.hasData, isFalse);
      expect(ticket.highestByCondition, 0);
    });

    test('the saved copy has the same shape as the server answer', () {
      final ticket = AverageTicketModel.fromJson(_answer);

      final again = AverageTicketModel.fromJson(AverageTicketModel.toJson(ticket));

      expect(again.globalAverage, 45000);
      expect(again.byCondition, ticket.byCondition);
    });
  });

  group('AverageTicketRepositoryImpl: network falling back to cache', () {
    late AppDatabase db;
    late bool offline;
    late int statusCode;

    AverageTicketRepositoryImpl repository() => AverageTicketRepositoryImpl(
          remote: AnalyticsRemoteDataSource(
            apiClient: ApiClient(
              baseUrl: 'https://analytics.test',
              client: MockClient((request) async {
                expect(request.url.path, '/analytics/average-ticket/');
                if (offline) throw http.ClientException('no network');
                return http.Response(jsonEncode(_answer), statusCode);
              }),
            ),
          ),
          cache: ResponseCache(db),
        );

    setUp(() {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      offline = false;
      statusCode = 200;
    });

    tearDown(() => db.close());

    test('online, the answer is returned and saved', () async {
      expect((await repository().getAverageTicket()).globalAverage, 45000);

      final saved = await ResponseCache(db)
          .read(AverageTicketRepositoryImpl.cacheOwner, AverageTicketRepositoryImpl.cacheKey);
      expect(saved, isNotNull);
    });

    test('offline, the saved copy is shown (a new cache, as after a restart)', () async {
      await repository().getAverageTicket();
      offline = true;

      final ticket = await repository().getAverageTicket();

      expect(ticket.byCondition[MaterialConditionEnum.GOOD], 30000);
    });

    test('offline with nothing saved, the user is told there is no connection', () {
      offline = true;

      expect(repository().getAverageTicket(), throwsA(isA<NoConnectionException>()));
    });

    test('a server failure with nothing saved is a readable error', () {
      statusCode = 500;

      expect(repository().getAverageTicket(), throwsA(isA<DataException>()));
    });
  });

  group('AverageTicketViewModel', () {
    final ticket = AverageTicketModel.fromJson(_answer);

    test('loading, then the figures', () async {
      final repo = _ScriptedRepository([ticket])..gate = Completer();
      final vm = AverageTicketViewModel(getAverageTicket: GetAverageTicketUseCase(repo));

      final load = vm.load();
      expect(vm.isLoading, isTrue);
      repo.gate!.complete();
      await load;

      expect(vm.isLoading, isFalse);
      expect(vm.ticket?.globalAverage, 45000);
      expect(vm.error, isNull);
    });

    test('loads once; "Try again" forces a reload', () async {
      final repo = _ScriptedRepository([ticket, ticket]);
      final vm = AverageTicketViewModel(getAverageTicket: GetAverageTicketUseCase(repo));

      await vm.load();
      await vm.load();
      expect(repo.calls, 1);

      await vm.load(force: true);
      expect(repo.calls, 2);
    });

    test('an error is shown only when there is nothing else to show', () async {
      final repo = _ScriptedRepository([const NoConnectionException(), ticket, const NoConnectionException()]);
      final vm = AverageTicketViewModel(getAverageTicket: GetAverageTicketUseCase(repo));

      await vm.load();
      expect(vm.error, isNotNull);
      expect(vm.isLoading, isFalse, reason: 'no endless spinner');

      await vm.load(force: true);
      expect(vm.error, isNull);

      await vm.load(force: true);
      expect(vm.error, isNull, reason: 'the figures already on screen stay');
      expect(vm.ticket?.globalAverage, 45000);
    });
  });

  group('AverageTicketCard', () {
    Future<_ScriptedRepository> pump(WidgetTester tester, List<Object> results) async {
      final repo = _ScriptedRepository(results);
      final vm = AverageTicketViewModel(getAverageTicket: GetAverageTicketUseCase(repo));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AverageTicketCard(viewModel: vm))));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows the global average in COP and a row per condition', (tester) async {
      await pump(tester, [AverageTicketModel.fromJson(_answer)]);

      expect(find.text(copPrice(45000)), findsOneWidget);
      expect(find.text('\$45.000 COP'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('\$60.000 COP'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('without sales it says so instead of showing \$0', (tester) async {
      await pump(tester, [AverageTicket.empty]);

      expect(find.byKey(const Key('average-ticket-empty')), findsOneWidget);
      expect(find.byKey(const Key('average-ticket-global')), findsNothing);
    });

    testWidgets('an error offers to try again', (tester) async {
      final repo = await pump(tester, [const NoConnectionException(), AverageTicketModel.fromJson(_answer)]);

      expect(find.byKey(const Key('average-ticket-error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('average-ticket-retry')));
      await tester.pumpAndSettle();

      expect(repo.calls, 2);
      expect(find.text('\$45.000 COP'), findsOneWidget);
    });
  });
}
