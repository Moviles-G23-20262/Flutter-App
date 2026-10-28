import 'dart:convert';
import 'dart:io';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/analytics_event_remote_data_source.dart';
import 'package:flutter_front_end/model/entities/enums.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/analytics_event_repository_impl.dart';
import 'package:flutter_front_end/model/services/analytics_sync_service.dart';
import 'package:flutter_front_end/model/use_cases/track_event_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Network implements ConnectivityRepository {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => const Stream.empty();
}

void main() {
  late Directory dir;
  late _Network network;
  late AnalyticsEventRepositoryImpl repository;
  late TrackEventUseCase track;

  // Every request the fake server saw, and the status it answers with.
  late List<List<Map<String, dynamic>>> batches;
  late List<int> statuses;

  AnalyticsSyncService service() {
    AnalyticsSyncService.reset();
    final client = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        expect(request.url.path, '/analytics-events/batch');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        batches.add((body['events'] as List).cast<Map<String, dynamic>>());
        final status = statuses.isEmpty ? 201 : statuses.removeAt(0);
        return http.Response('{}', status);
      }),
    );
    return AnalyticsSyncService(
      remote: AnalyticsEventRemoteDataSource(apiClient: client),
      connectivity: network,
      directory: () async => dir,
    );
  }

  File file(String name) => File('${dir.path}/$name');
  int lines(String name) => file(name).existsSync() ? file(name).readAsLinesSync().length : 0;

  Future<void> queue(int count) async {
    for (var i = 0; i < count; i++) {
      await track.execute(AnalyticsEventType.LISTING_VIEW, materialId: 'm$i');
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('analytics_sync');
    network = _Network();
    batches = [];
    statuses = [];
    repository = AnalyticsEventRepositoryImpl(directory: () async => dir);
    track = TrackEventUseCase(repository);
  });

  tearDown(() {
    AnalyticsSyncService.reset();
    dir.deleteSync(recursive: true);
  });

  test('is a singleton', () {
    final first = service();
    expect(AnalyticsSyncService(remote: AnalyticsEventRemoteDataSource(apiClient: ApiClient(baseUrl: 'x', client: http.Client())), connectivity: network), same(first));
    expect(AnalyticsSyncService.instance, same(first));
  });

  test('sends the queue in batches of 10 and empties the files', () async {
    await queue(25);

    await service().syncNow();

    expect(batches.map((b) => b.length), [10, 10, 5]);
    expect(batches.first.first['client_id'], isNotEmpty);
    expect(batches.first.first['clientCreatedAt'], isNotEmpty);
    expect(lines('pending.jsonl'), 0);
    expect(file('pending.sending.jsonl').existsSync(), isFalse);
  });

  test('a failed batch stays queued, the accepted ones are gone', () async {
    await queue(25);
    statuses = [201, 500]; // second batch fails, the sync stops there

    await service().syncNow();

    expect(batches, hasLength(2));
    expect(lines('pending.jsonl'), 15);
    expect(file('pending.sending.jsonl').existsSync(), isFalse);

    // The next pass retries those 15, nothing duplicated.
    batches.clear();
    await service().syncNow();
    expect(batches.map((b) => b.length), [10, 5]);
    expect(lines('pending.jsonl'), 0);
  });

  test('does nothing while offline and keeps the events', () async {
    await queue(3);
    network.online = false;

    await service().syncNow();

    expect(batches, isEmpty);
    expect(lines('pending.jsonl'), 3);
  });

  test('a .sending file left by a crash goes back to the queue and is sent', () async {
    await queue(2);
    file('pending.jsonl').renameSync(file('pending.sending.jsonl').path);
    await queue(1);

    await service().syncNow();

    expect(batches.expand((b) => b), hasLength(3));
    expect(lines('pending.jsonl'), 0);
    expect(file('pending.sending.jsonl').existsSync(), isFalse);
  });

  test('an event tracked while uploading lands in the next pending.jsonl', () async {
    await queue(2);
    final sync = service();

    final pass = sync.syncNow();
    await queue(1); // races with the swap: ends up in one of the two files, never lost
    await pass;
    await sync.syncNow();

    expect(batches.expand((b) => b).map((e) => e['client_id']).toSet(), hasLength(3));
    expect(lines('pending.jsonl'), 0);
  });

  test('isSyncing is true during the upload and notifies its listeners', () async {
    await queue(1);
    final sync = service();
    final seen = <bool>[];
    sync.addListener(() => seen.add(sync.isSyncing));

    await sync.syncNow();

    expect(seen, [true, false]);
    expect(sync.isSyncing, isFalse);
  });

  test('corrupt lines are skipped and do not block the rest', () async {
    await queue(1);
    file('pending.jsonl').writeAsStringSync('not json\n', mode: FileMode.append);
    await queue(1);

    await service().syncNow();

    expect(batches.expand((b) => b), hasLength(2));
    expect(lines('pending.jsonl'), 0);
  });
}
