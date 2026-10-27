import 'dart:convert';
import 'dart:io';

import 'package:flutter_front_end/model/repositories/impl/analytics_event_repository_impl.dart';
import 'package:flutter_front_end/model/entities/analytics_event.dart';
import 'package:flutter_front_end/model/entities/enums.dart';
import 'package:flutter_front_end/model/repositories/analytics_event_repository.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('pending.jsonl queue', () {
    late Directory dir;
    late AnalyticsEventRepositoryImpl repository;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('analytics_queue');
      repository = AnalyticsEventRepositoryImpl(directory: () async => dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    List<Map<String, dynamic>> lines() => File('${dir.path}/pending.jsonl')
        .readAsLinesSync()
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .toList();

    test('appends one JSON line per event with client_id and clientCreatedAt', () async {
      final useCase = TrackEventUseCase(repository, now: () => fixedNow);

      await useCase.execute(
        AnalyticsEventType.CONTACT_SELLER,
        materialId: 'm1',
        metadata: {'chatRoomId': 'r1'},
      );
      await useCase.execute(AnalyticsEventType.LISTING_VIEW, materialId: 'm2');

      final saved = lines();
      expect(saved, hasLength(2));
      expect(saved[0]['eventType'], 'CONTACT_SELLER');
      expect(saved[0]['materialId'], 'm1');
      expect(saved[0]['metadata'], {'chatRoomId': 'r1'});
      expect(saved[0]['occurredAt'], '2026-10-12T15:30:00.000Z');
      expect(saved[0]['clientCreatedAt'], '2026-10-12T15:30:00.000Z');
      expect(saved[0]['client_id'], matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(saved[1].containsKey('metadata'), isFalse);
      expect(saved[1]['client_id'], isNot(saved[0]['client_id']));
    });

    test('an event survives the JSON round trip', () async {
      final useCase = TrackEventUseCase(repository, now: () => fixedNow);
      await useCase.execute(AnalyticsEventType.CONTACT_SELLER, materialId: 'm1', metadata: {'a': 1});

      final event = AnalyticsEvent.fromJson(lines().single);
      expect(event.type, AnalyticsEventType.CONTACT_SELLER);
      expect(event.clientCreatedAt, fixedNow);
      expect(event.metadata, {'a': 1});
    });
  });
}
