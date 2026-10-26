import 'dart:convert';

import 'package:flutter_front_end/model/repositories/impl/analytics_event_repository_impl.dart';
import 'package:flutter_front_end/model/data_sources/analytics_event_remote_data_source.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/enums.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Recorder implements AnalyticsEventRepository {
  final sent = <AnalyticsEvent>[];
  Object? error;

  @override
  Future<void> track(AnalyticsEvent event) async {
    if (error != null) throw error!;
    sent.add(event);
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 10, 12, 15, 30);

  group('TrackEventUseCase', () {
    test('hands the event to the repository with the time it happened', () async {
      final repo = _Recorder();
      final useCase = TrackEventUseCase(repo, now: () => fixedNow);

      await useCase.execute(
        AnalyticsEventType.CONTACT_SELLER,
        materialId: 'm1',
        metadata: {'chatRoomId': 'r1'},
      );

      final event = repo.sent.single;
      expect(event.type, AnalyticsEventType.CONTACT_SELLER);
      expect(event.materialId, 'm1');
      expect(event.metadata, {'chatRoomId': 'r1'});
      expect(event.occurredAt, fixedNow);
    });

    test('a network or server failure is swallowed', () async {
      final repo = _Recorder();
      final useCase = TrackEventUseCase(repo);

      for (final error in [
        const NetworkException('offline'),
        Exception('boom'),
        StateError('bad state'),
      ]) {
        repo.error = error;
        await expectLater(useCase.execute(AnalyticsEventType.LISTING_VIEW, materialId: 'm1'), completes);
      }
      expect(repo.sent, isEmpty);
    });
  });

  group('POST /analytics-events', () {
    late http.BaseRequest seen;
    late String body;

    AnalyticsEventRepositoryImpl repository({String? token, int status = 201}) {
      final client = ApiClient(
        baseUrl: 'https://api.test/',
        client: MockClient.streaming((request, stream) async {
          seen = request;
          body = await utf8.decodeStream(stream);
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), status);
        }),
      )..authToken = token;
      return AnalyticsEventRepositoryImpl(AnalyticsEventRemoteDataSource(apiClient: client));
    }

    test('sends the payload with the Bearer token', () async {
      final useCase = TrackEventUseCase(repository(token: 'jwt'), now: () => fixedNow);

      await useCase.execute(
        AnalyticsEventType.CONTACT_SELLER,
        materialId: 'm1',
        metadata: {'chatRoomId': 'r1'},
      );

      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://api.test/analytics-events');
      expect(seen.headers['Authorization'], 'Bearer jwt');
      expect(jsonDecode(body), {
        'eventType': 'CONTACT_SELLER',
        'materialId': 'm1',
        'metadata': {'chatRoomId': 'r1'},
        'occurredAt': '2026-10-12T15:30:00.000Z',
      });
    });

    test('leaves out the optional fields it does not have', () async {
      final useCase = TrackEventUseCase(repository(token: 'jwt'), now: () => fixedNow);

      await useCase.execute(AnalyticsEventType.LISTING_VIEW, materialId: 'm1');

      expect(jsonDecode(body), {
        'eventType': 'LISTING_VIEW',
        'materialId': 'm1',
        'occurredAt': '2026-10-12T15:30:00.000Z',
      });
    });

    test('a rejected event (server error) does not throw', () async {
      final useCase = TrackEventUseCase(repository(token: 'jwt', status: 500));

      await expectLater(useCase.execute(AnalyticsEventType.LISTING_VIEW, materialId: 'm1'), completes);
    });
  });
}
