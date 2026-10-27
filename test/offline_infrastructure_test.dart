import 'dart:async';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/lru_cache.dart';
import 'package:flutter_front_end/model/data_sources/local/outbox_store.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/entities/pending_items.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/services/outbox_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppDatabase _memoryDatabase() => AppDatabase.withFactory(databaseFactoryFfi);

class _FakeConnectivity implements ConnectivityRepository {
  final StreamController<bool> changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> watch() => changes.stream;
}

/// Records what was sent; [failNext] decides how the next sends fail.
class _FakeSender implements OutboxSender {
  final List<String> sent = [];
  final List<Object> failures = [];
  Completer<void>? gate;

  Future<void> _send(String label) async {
    if (gate != null) await gate!.future;
    if (failures.isNotEmpty) throw failures.removeAt(0);
    sent.add(label);
  }

  @override
  Future<String> uploadPhoto(String path) async {
    await _send('upload:$path');
    return 'https://cdn.test/${path.split('/').last}';
  }

  @override
  Future<void> createListing(Map<String, dynamic> body) => _send('listing:${body['title']}');

  @override
  Future<void> sendMessage(PendingMessage message) => _send('${message.chatRoomId}:${message.content}');

  @override
  Future<void> sendAction(PendingAction action) => _send('${action.kind.name}:${action.groupId}');
}

void main() {
  sqfliteFfiInit();

  group('LruCache', () {
    test('drops the least recently used entry, and a read counts as a use', () {
      final cache = LruCache<String, int>(2)
        ..put('home', 1)
        ..put('chat', 2);

      expect(cache.get('home'), 1); // "chat" is now the least recently used
      cache.put('inbox', 3);

      expect(cache.containsKey('chat'), isFalse);
      expect(cache.keys, ['home', 'inbox']);
    });

    test('writing an existing key replaces it without growing', () {
      final cache = LruCache<String, int>(2)
        ..put('home', 1)
        ..put('home', 5);

      expect(cache.length, 1);
      expect(cache.get('home'), 5);
    });
  });

  group('ResponseCache', () {
    late AppDatabase db;
    late DateTime now;
    late ResponseCache cache;

    setUp(() {
      db = _memoryDatabase();
      now = DateTime(2026, 10, 26, 9);
      cache = ResponseCache(db, now: () => now);
    });
    tearDown(() => db.close());

    test('keeps one copy per user and screen, and still has it after a restart', () async {
      await cache.save('ana', 'home', [
        {'id': 'm1'},
      ]);
      await cache.save('luis', 'home', [
        {'id': 'm2'},
      ]);

      // A new ResponseCache has an empty memory level, so this read comes from SQLite.
      final afterRestart = ResponseCache(db);
      final saved = await afterRestart.read('ana', 'home');

      expect(saved!.data, [
        {'id': 'm1'},
      ]);
      expect(saved.savedAt, now);
      expect(await afterRestart.read('ana', 'inbox'), isNull);
    });

    test('a new answer replaces the saved one', () async {
      await cache.save('ana', 'home', ['old']);
      await cache.save('ana', 'home', ['new']);

      expect((await ResponseCache(db).read('ana', 'home'))!.data, ['new']);
    });

    test('long lists go through the isolate and come back the same', () async {
      final longList = List.generate(ResponseCache.isolateListLength + 50, (i) => {'id': 'm$i', 'title': 'x' * 500});
      await cache.save('ana', 'home', longList);

      expect((await ResponseCache(db).read('ana', 'home'))!.data, longList);
    });

    group('networkFirst', () {
      Future<CachedResult<List<String>>> load(Future<Object?> Function() fetch) => cache.networkFirst(
            ownerId: 'ana',
            key: 'home',
            fetch: fetch,
            parse: (json) => (json as List).cast<String>(),
          );

      test('saves a fresh answer', () async {
        final result = await load(() async => ['m1']);

        expect(result.fromCache, isFalse);
        expect(result.data, ['m1']);
        expect((await cache.read('ana', 'home'))!.data, ['m1']);
      });

      test('offline it returns the saved copy with the time it was saved', () async {
        await load(() async => ['m1']);
        final savedAt = now;
        now = now.add(const Duration(hours: 2));

        final result = await load(() => throw const NetworkException('offline'));

        expect(result.fromCache, isTrue);
        expect(result.data, ['m1']);
        expect(result.savedAt, savedAt);
      });

      test('a 5xx also falls back to the saved copy', () async {
        await load(() async => ['m1']);

        final result = await load(() => throw const ApiException(503, 'down'));

        expect(result.data, ['m1']);
      });

      test('offline with nothing saved, the error reaches the caller', () async {
        expect(load(() => throw const NetworkException('offline')), throwsA(isA<NetworkException>()));
      });

      test('a 4xx is the server answering, so it is not hidden behind the copy', () async {
        await load(() async => ['m1']);

        expect(load(() => throw const ApiException(403, 'no')), throwsA(isA<ApiException>()));
      });
    });
  });

  group('OutboxStore', () {
    late AppDatabase db;
    late OutboxStore store;

    setUp(() {
      db = _memoryDatabase();
      store = OutboxStore(db);
    });
    tearDown(() => db.close());

    test('rows belong to their owner and come back oldest first', () async {
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'hi');
      await store.enqueueMessage(ownerId: 'luis', chatRoomId: 'r1', content: 'not mine');
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r2', content: 'second');

      final mine = await store.messages('ana');
      expect(mine.map((m) => m.content), ['hi', 'second']);
      expect((await store.messages('ana', chatRoomId: 'r2')).single.content, 'second');
    });

    test('a listing keeps its payload and photo paths', () async {
      await store.enqueueListing(
        ownerId: 'ana',
        payload: {'title': 'Calculus book', 'price': '20000.00'},
        photoPaths: ['/docs/pending_photos/a.jpg'],
      );

      final listing = (await store.listings('ana')).single;
      expect(listing.title, 'Calculus book');
      expect(listing.payload['price'], '20000.00');
      expect(listing.photoPaths, ['/docs/pending_photos/a.jpg']);
      expect(listing.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('retry counts the attempt; refused keeps the reason; sent removes the row', () async {
      final a = await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'a');
      final b = await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'b');
      final changes = <void>[];
      final subscription = store.changes.listen(changes.add);

      await store.markRetry(PendingKind.message, a.id, 'offline');
      await store.markRefused(PendingKind.message, b.id, 'Chat room not found');
      var rows = await store.messages('ana');
      expect(rows[0].status, PendingStatus.waiting);
      expect(rows[0].attempts, 1);
      expect(rows[1].status, PendingStatus.refused);
      expect(rows[1].lastError, 'Chat room not found');

      await store.markSent(PendingKind.message, a.id);
      rows = await store.messages('ana');
      expect(rows.map((m) => m.content), ['b']);

      await Future<void>.delayed(Duration.zero);
      expect(changes, hasLength(3));
      await subscription.cancel();
    });
  });

  group('OutboxSyncService', () {
    late AppDatabase db;
    late OutboxStore store;
    late _FakeSender sender;
    late _FakeConnectivity connectivity;
    late OutboxSyncService sync;

    setUp(() {
      db = _memoryDatabase();
      store = OutboxStore(db);
      sender = _FakeSender();
      connectivity = _FakeConnectivity();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: connectivity,
        baseRetryDelay: const Duration(milliseconds: 30),
      );
    });
    tearDown(() async {
      sync.dispose();
      await db.close();
    });

    test('sends listings first, then messages oldest first, and empties the outbox', () async {
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'hi');
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Book'});
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'still there?');

      sync.start('ana');
      await sync.flush();

      expect(sender.sent, ['listing:Book', 'r1:hi', 'r1:still there?']);
      expect(await store.messages('ana'), isEmpty);
      expect(await store.listings('ana'), isEmpty);
    });

    test('without network the item stays, and the retry timer delivers it later', () async {
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'hi');
      sender.failures.add(const NetworkException('offline'));

      sync.start('ana');
      await sync.flush();
      expect(sender.sent, isEmpty);
      expect((await store.messages('ana')).single.attempts, 1);
      expect(sync.retryScheduled, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      await sync.flush();

      expect(sender.sent, ['r1:hi']);
      expect(sync.retryScheduled, isFalse);
    });

    test('a retry-later stops the flush, so nothing after it overtakes it', () async {
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'first');
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r2', content: 'second');
      sender.failures.add(const ApiException(503, 'down'));

      sync.start('ana');
      await sync.flush();

      expect(sender.sent, isEmpty);
      expect((await store.messages('ana')).every((m) => m.status == PendingStatus.waiting), isTrue);
    });

    test('a refused message keeps its reason and holds back the rest of that chat only', () async {
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'refused');
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'after it');
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r2', content: 'other chat');
      sender.failures.add(const ApiException(403, 'You are not part of this chat'));

      sync.start('ana');
      await sync.flush();

      expect(sender.sent, ['r2:other chat']);
      final left = await store.messages('ana');
      expect(left.map((m) => m.content), ['refused', 'after it']);
      expect(left.first.status, PendingStatus.refused);
      expect(left.first.lastError, 'You are not part of this chat');
      expect(left.last.status, PendingStatus.waiting);
      expect(sync.retryScheduled, isFalse, reason: 'a refusal is final; retrying cannot fix it');
    });

    test('only one flush runs at a time, so nothing is sent twice', () async {
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'hi');
      sender.gate = Completer<void>();

      sync.start('ana'); // first flush, now waiting on the gate
      final second = sync.flush();
      final third = sync.flush();
      expect(sync.isFlushing, isTrue);
      sender.gate!.complete();
      await Future.wait([second, third]);

      expect(sender.sent, ['r1:hi']);
    });

    test('an item queued during a flush is sent right after it', () async {
      sender.gate = Completer<void>();
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'first');
      sync.start('ana');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'queued meanwhile');
      final done = sync.flush();
      sender.gate!.complete();
      await done;

      expect(sender.sent, ['r1:first', 'r1:queued meanwhile']);
    });

    test("never sends another user's rows, and logging out keeps them for later", () async {
      await store.enqueueMessage(ownerId: 'luis', chatRoomId: 'r9', content: "luis's message");
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: "ana's message");

      sync.start('ana');
      await sync.flush();
      sync.stop();

      expect(sender.sent, ['r1:ana\'s message']);
      expect((await store.messages('luis')).single.content, "luis's message");

      sync.start('luis');
      await sync.flush();
      expect(sender.sent.last, "r9:luis's message");
    });

    test('flushes when the connection comes back', () async {
      sync.start('ana');
      await sync.flush();
      await store.enqueueMessage(ownerId: 'ana', chatRoomId: 'r1', content: 'written offline');

      expect(sender.sent, isEmpty);
      connectivity.changes.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(sender.sent, ['r1:written offline']);
    });
  });
}
