import 'dart:async';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/core/isolates/home_feed_isolate.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/outbox_store.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/pending_items.dart';
import 'package:flutter_front_end/model/entities/user_summary.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/services/outbox_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestNet implements ConnectivityRepository {
  final _ctrl = StreamController<bool>.broadcast();
  @override
  Future<bool> isOnline() async => true;
  @override
  Stream<bool> watch() => _ctrl.stream;
  void dispose() => _ctrl.close();
}

class _GateSender implements OutboxSender {
  Completer<void>? gate;
  bool shouldFail = false;

  @override
  Future<void> sendMessage(PendingMessage message) async {
    if (gate != null) await gate!.future;
    if (shouldFail) throw const NetworkException('offline');
  }

  @override
  Future<String> uploadPhoto(String path) async => 'https://cdn.test/a.jpg';
  @override
  Future<void> createListing(Map<String, dynamic> body) async {}
  @override
  Future<void> sendAction(PendingAction action) async {}
}

MaterialEntity _listing(String id, UserSummary seller, MaterialCategoryEnum cat) => MaterialEntity(
      id: id,
      title: 'Item $id',
      description: 'Good item for uniandes course',
      price: 25000,
      condition: MaterialConditionEnum.GOOD,
      status: MaterialStatusEnum.AVAILABLE,
      imageUrls: const [],
      sellerId: seller.id,
      seller: seller,
      category: cat,
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    );

void main() {
  setUpAll(sqfliteFfiInit);

  test('computeHomeFeedProjection ranks top 4 featured sellers and category counts in a compute() isolate', () async {
    const ana = UserSummary(id: 's1', fullName: 'Ana Gomez', major: 'ISIS', rating: 4.9);
    const luis = UserSummary(id: 's2', fullName: 'Luis Perez', major: 'IIND', rating: 4.7);
    const sofia = UserSummary(id: 's3', fullName: 'Sofia Diaz', major: 'MATE', rating: 5.0);

    final listings = [
      _listing('m1', ana, MaterialCategoryEnum.BOOKS),
      _listing('m2', ana, MaterialCategoryEnum.BOOKS),
      _listing('m3', ana, MaterialCategoryEnum.CALCULATORS),
      _listing('m4', luis, MaterialCategoryEnum.BOOKS),
      _listing('m5', luis, MaterialCategoryEnum.LAB_EQUIPMENT),
      _listing('m6', sofia, MaterialCategoryEnum.FURNITURE),
    ];

    final result = await computeHomeFeedProjection(listings, forceIsolate: true);

    expect(result.featuredSellers.map((s) => s.seller.id).toList(), ['s1', 's2', 's3']);
    expect(result.featuredSellers.first.items, 3);
    expect(result.categoryCounts['Books'], 3);
    expect(result.categoryCounts['Calculators'], 1);
  });

  test('OutboxSyncService broadcasts syncing -> idle and syncing -> retrying over syncStatusStream', () async {
    final db = AppDatabase.withFactory(databaseFactoryFfi);
    final store = OutboxStore(db);
    final net = _TestNet();
    final sender = _GateSender();
    final sync = OutboxSyncService(
      store: store,
      sender: sender,
      connectivity: net,
      baseRetryDelay: const Duration(minutes: 5),
    );
    final statuses = <OutboxSyncStatus>[];
    final sub = sync.syncStatusStream.listen(statuses.add);

    sync.start('u1');
    await store.enqueueMessage(ownerId: 'u1', chatRoomId: 'r1', content: 'Sync test');

    sender.gate = Completer<void>();
    final flushFuture = sync.flush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sync.syncStatus, OutboxSyncStatus.syncing);

    sender.gate!.complete();
    await flushFuture;
    expect(sync.syncStatus, OutboxSyncStatus.idle);
    expect(statuses, containsAllInOrder([OutboxSyncStatus.syncing, OutboxSyncStatus.idle]));

    // Now simulate failure -> transitions to retrying.
    statuses.clear();
    await store.enqueueMessage(ownerId: 'u1', chatRoomId: 'r1', content: 'Retry test');
    sender.gate = null;
    sender.shouldFail = true;
    await sync.flush();
    expect(sync.syncStatus, OutboxSyncStatus.retrying);
    expect(statuses, containsAllInOrder([OutboxSyncStatus.syncing, OutboxSyncStatus.retrying]));

    await sub.cancel();
    sync.dispose();
    net.dispose();
    await store.dispose();
    await db.close();
  });
}
