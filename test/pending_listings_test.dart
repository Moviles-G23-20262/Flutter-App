import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/core/isolates/photo_compressor.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/outbox_store.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/new_listing_data.dart';
import 'package:flutter_front_end/model/entities/pending_items.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/impl/pending_listing_repository_impl.dart';
import 'package:flutter_front_end/model/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/model/entities/price_stats.dart';
import 'package:flutter_front_end/model/services/outbox_sync_service.dart';
import 'package:flutter_front_end/model/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/pending_listing_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/view/screens/new_listing_smart_screen.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/smart_listing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _photo = Uint8List.fromList(List.generate(32, (i) => i));

/// A real (1x1) PNG: the sell screen draws a preview of the picked photo.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

AppDatabase _memoryDatabase() => AppDatabase.withFactory(databaseFactoryFfi);

class _Online implements ConnectivityRepository {
  bool online = true;
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => changes.stream;
}

/// Records every upload and listing; [failures] decides how the next calls fail.
class _Sender implements OutboxSender {
  final uploads = <String>[];
  final listings = <Map<String, dynamic>>[];
  final failures = <Object>[];

  Never _fail() => throw failures.removeAt(0);

  @override
  Future<String> uploadPhoto(String path) async {
    if (failures.isNotEmpty && failures.first is _FailOn && (failures.first as _FailOn).path == path) {
      failures.removeAt(0);
      throw const NetworkException('offline');
    }
    uploads.add(path);
    return 'https://cdn.test/${p.basename(path)}';
  }

  @override
  Future<void> createListing(Map<String, dynamic> body) async {
    if (failures.isNotEmpty && failures.first is! _FailOn) _fail();
    listings.add(body);
  }

  @override
  Future<void> sendMessage(PendingMessage message) async {}

  @override
  Future<void> sendAction(PendingAction action) async {}
}

/// "The upload of [path] fails with no network."
class _FailOn {
  final String path;
  _FailOn(this.path);
}

NewListingData _data({String title = 'Calculus'}) => NewListingData(
      title: title,
      description: 'Barely used',
      courseCode: 'MATE 1203',
      price: 35000,
      condition: MaterialConditionEnum.GOOD,
      category: MaterialCategoryEnum.BOOKS,
    );

void main() {
  sqfliteFfiInit();

  late Directory documents;
  late AppDatabase db;
  late OutboxStore store;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('pending_listings');
    db = _memoryDatabase();
    store = OutboxStore(db);
  });
  tearDown(() async {
    await db.close();
    documents.deleteSync(recursive: true);
  });

  /// A compressed photo on disk, as the compressor would leave it.
  String photoFile(String name) {
    final file = File(p.join(documents.path, 'pending_photos', name))
      ..createSync(recursive: true)
      ..writeAsBytesSync(_photo);
    return file.path;
  }

  group('database', () {
    test('a phone with the old schema keeps its queued listings when it upgrades to v3', () async {
      final path = p.join(documents.path, 'old.db');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE pending_listings (
                id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, payload TEXT NOT NULL, photo_paths TEXT NOT NULL,
                created_at INTEGER NOT NULL, status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT
              )''');
            await db.insert('pending_listings', {
              'id': 'old-1',
              'owner_id': 'ana',
              'payload': '{"title":"Old book"}',
              'photo_paths': '["/a.jpg"]',
              'created_at': 1,
              'status': 'waiting',
            });
          },
        ),
      );
      await old.close();

      final upgraded = AppDatabase.withFactory(databaseFactoryFfi, path: path);
      final listing = (await OutboxStore(upgraded).listings('ana')).single;

      expect(listing.title, 'Old book');
      expect(listing.photoPaths, ['/a.jpg']);
      expect(listing.uploadedUrls, isEmpty);
      await upgraded.close();
    });

    test('the uploaded photo urls are saved with the listing', () async {
      final queued = await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Book'}, photoPaths: ['/a.jpg', '/b.jpg']);

      await store.saveUploadedUrls(queued.id, ['https://cdn.test/a.jpg']);

      final listing = (await store.listings('ana')).single;
      expect(listing.uploadedUrls, ['https://cdn.test/a.jpg']);
      expect(listing.photoPaths, ['/a.jpg', '/b.jpg']);
    });
  });

  group('sync service: POST /uploads for each missing photo, then POST /materials', () {
    late _Sender sender;
    late _Online network;
    late OutboxSyncService sync;

    setUp(() {
      sender = _Sender();
      network = _Online();
      sync = OutboxSyncService(
        store: store,
        sender: sender,
        connectivity: network,
        baseRetryDelay: const Duration(hours: 1), // the tests flush by hand
      );
    });
    tearDown(() => sync.dispose());

    test('uploads every photo in order, then creates the listing with all their urls', () async {
      final a = photoFile('a.jpg');
      final b = photoFile('b.jpg');
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculus', 'price': '35000.00'}, photoPaths: [a, b]);

      sync.start('ana');
      await sync.flush();

      expect(sender.uploads, [a, b]);
      expect(sender.listings.single, {
        'title': 'Calculus',
        'price': '35000.00',
        'imageUrls': ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg'],
      });
      expect(await store.listings('ana'), isEmpty);
    });

    test('the compressed photos are deleted from the phone once the listing is published', () async {
      final a = photoFile('a.jpg');
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculus'}, photoPaths: [a]);

      sync.start('ana');
      await sync.flush();

      expect(File(a).existsSync(), isFalse);
    });

    test('a connection lost half way keeps the photos already uploaded and never uploads them twice', () async {
      final a = photoFile('a.jpg');
      final b = photoFile('b.jpg');
      final c = photoFile('c.jpg');
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculus'}, photoPaths: [a, b, c]);
      sender.failures.add(_FailOn(c));

      sync.start('ana');
      await sync.flush();

      var listing = (await store.listings('ana')).single;
      expect(listing.status, PendingStatus.waiting);
      expect(listing.uploadedUrls, ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg']);
      expect(listing.attempts, 1);
      expect(File(a).existsSync(), isTrue);

      await sync.flush();

      expect(sender.uploads, [a, b, c]); // a and b only once
      expect(sender.listings.single['imageUrls'], hasLength(3));
      expect(await store.listings('ana'), isEmpty);
    });

    test('a listing without photos only needs POST /materials', () async {
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculator'});

      sync.start('ana');
      await sync.flush();

      expect(sender.uploads, isEmpty);
      expect(sender.listings.single['imageUrls'], isEmpty);
    });

    test('a listing the server refuses stays as "not published" with the reason and its photos', () async {
      final a = photoFile('a.jpg');
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculus'}, photoPaths: [a]);
      sender.failures.add(const ApiException(400, 'price must be a positive number'));

      sync.start('ana');
      await sync.flush();

      final listing = (await store.listings('ana')).single;
      expect(listing.status, PendingStatus.refused);
      expect(listing.lastError, 'price must be a positive number');
      expect(listing.uploadedUrls, ['https://cdn.test/a.jpg']);
      expect(File(a).existsSync(), isTrue);
    });

    test('a server error is temporary: the listing keeps waiting', () async {
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculus'});
      sender.failures.add(const ApiException(503, 'down'));

      sync.start('ana');
      await sync.flush();

      expect((await store.listings('ana')).single.status, PendingStatus.waiting);
    });

    test('it publishes by itself when the connection comes back', () async {
      await store.enqueueListing(ownerId: 'ana', payload: {'title': 'Calculus'});
      sender.failures.add(const NetworkException('offline'));
      sync.start('ana');
      await sync.flush();
      expect(sender.listings, isEmpty);

      network.changes.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(sender.listings, hasLength(1));
    });
  });

  group('PendingListingRepositoryImpl', () {
    late PendingListingRepositoryImpl repository;

    setUp(() => repository = PendingListingRepositoryImpl(store));

    test('queues the listing body (same as POST /materials) and the compressed photo paths', () async {
      final a = photoFile('a.jpg');

      final queued = await QueueListingUseCase(repository).execute(ownerId: 'ana', data: _data(), photoPaths: [a]);

      final saved = (await store.listings('ana')).single;
      expect(saved.id, queued.id);
      expect(saved.payload, {
        'title': 'Calculus',
        'description': 'Barely used',
        'courseCode': 'MATE 1203',
        'price': '35000.00',
        'condition': 'GOOD',
        'category': 'BOOKS',
      });
      expect(saved.photoPaths, [a]);
      expect(saved.price, '35000.00');
    });

    test('watch follows the queue: queued, then discarded', () async {
      final emissions = <List<String>>[];
      final sub = repository.watch('ana').listen((l) => emissions.add([for (final x in l) x.title]));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final queued = await repository.queue(ownerId: 'ana', data: _data(), photoPaths: []);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await DiscardPendingListingUseCase(repository).execute(queued.id);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();

      expect(emissions.first, isEmpty);
      expect(emissions, contains(equals(['Calculus'])));
      expect(emissions.last, isEmpty);
    });

    test('discarding deletes the row and its photo files', () async {
      final a = photoFile('a.jpg');
      final queued = await repository.queue(ownerId: 'ana', data: _data(), photoPaths: [a]);

      await repository.discard(queued.id);

      expect(await store.listings('ana'), isEmpty);
      expect(File(a).existsSync(), isFalse);
    });

    test('a listing belongs to its owner only', () async {
      await repository.queue(ownerId: 'ana', data: _data(), photoPaths: []);

      expect(await store.listings('luis'), isEmpty);
    });
  });

  group('SmartListingViewModel.publish with compression and the offline queue', () {
    late _Online network;
    late List<CompressedPhoto> compressed;
    late List<List<Uint8List>> compressedInputs;
    late List<NewListingData> published;
    late List<String> events;
    Object? publishError;
    late PendingListingRepositoryImpl queueRepo;

    SmartListingViewModel viewModel({bool withQueue = true, String? userId = 'ana', bool withNetworkCheck = true}) =>
        SmartListingViewModel(
          estimator: PriceEstimatorUseCase(repository: _Stats()),
          pickPhoto: (source) async => _photo,
          publishListing: (data) async {
            events.add('publish');
            if (publishError != null) throw publishError!;
            published.add(data);
          },
          compressPhotos: (photos) async {
            events.add('compress');
            compressedInputs.add(photos);
            compressed = [for (var i = 0; i < photos.length; i++) CompressedPhoto(path: photoFile('c$i.jpg'), bytes: Uint8List.fromList([9, i]))];
            return compressed;
          },
          queueListing: withQueue ? QueueListingUseCase(queueRepo) : null,
          connectivity: withNetworkCheck ? GetConnectivityUseCase(network) : null,
          userId: userId,
        );

    Future<bool> publish(SmartListingViewModel vm) async {
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.addPhoto(ImageSource.gallery);
      return vm.publish(title: 'Calculus', description: 'Barely used', courseCode: 'MATE 1203', price: '35000');
    }

    setUp(() {
      network = _Online();
      compressed = [];
      compressedInputs = [];
      published = [];
      events = [];
      publishError = null;
      queueRepo = PendingListingRepositoryImpl(store);
    });

    test('online: compresses first, publishes the compressed photos, and cleans up', () async {
      final vm = viewModel();

      expect(await publish(vm), isTrue);

      expect(events, ['compress', 'publish']);
      expect(compressedInputs.single.single, _photo); // the original goes in
      expect(published.single.images.single.bytes, [9, 0]); // the compressed one goes up
      expect(published.single.images.single.filename, 'c0.jpg');
      expect(vm.savedOffline, isFalse);
      expect(await store.listings('ana'), isEmpty);
      expect(File(compressed.single.path).existsSync(), isFalse);
      vm.dispose();
    });

    test('offline: saves the listing on the phone without trying the network', () async {
      network.online = false;
      final vm = viewModel();

      expect(await publish(vm), isTrue);

      expect(events, ['compress']); // no publish attempt, no waiting for a timeout
      expect(vm.savedOffline, isTrue);
      expect(vm.published, isTrue);
      expect(vm.publishError, isNull);
      final saved = (await store.listings('ana')).single;
      expect(saved.title, 'Calculus');
      expect(saved.photoPaths, [compressed.single.path]);
      expect(File(compressed.single.path).existsSync(), isTrue); // kept for the sync service
      vm.dispose();
    });

    test('a NoConnectionException while publishing also saves it on the phone', () async {
      publishError = const NoConnectionException();
      final vm = viewModel();

      expect(await publish(vm), isTrue);

      expect(events, ['compress', 'publish']);
      expect(vm.savedOffline, isTrue);
      expect((await store.listings('ana')).single.photoPaths, [compressed.single.path]);
      vm.dispose();
    });

    test('a listing the server rejects is not queued and its error is shown', () async {
      publishError = const DataException('Title is too long');
      final vm = viewModel();

      expect(await publish(vm), isFalse);

      expect(vm.publishError, 'Title is too long');
      expect(vm.savedOffline, isFalse);
      expect(await store.listings('ana'), isEmpty);
      expect(File(compressed.single.path).existsSync(), isFalse);
      vm.dispose();
    });

    test('without a signed-in user or a queue, being offline is an error, not a silent loss', () async {
      network.online = false;
      final vm = viewModel(userId: null);

      expect(await publish(vm), isFalse);

      expect(vm.publishError, const NoConnectionException().message);
      expect(vm.published, isFalse);
      vm.dispose();
    });

    test('the offline message is the one the product asks for', () {
      expect(SmartListingViewModel.savedOfflineMessage, "Saved on your phone. We'll publish it as soon as you reconnect.");
    });

    test('without a compressor the original photos are used', () async {
      final vm = SmartListingViewModel(
        estimator: PriceEstimatorUseCase(repository: _Stats()),
        pickPhoto: (source) async => _photo,
        publishListing: (data) async => published.add(data),
      );

      expect(await publish(vm), isTrue);
      expect(published.single.images.single.bytes, _photo);
      vm.dispose();
    });
  });

  group('Sell screen', () {
    testWidgets('shows "Saved on your phone..." when the listing was queued', (tester) async {
      final network = _Online()..online = false;
      final app = _NoApp();
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: NewListingSmartScreen(
          appState: app,
          viewModelFactory: () => SmartListingViewModel(
            estimator: PriceEstimatorUseCase(repository: _Stats()),
            pickPhoto: (source) async => _png,
            publishListing: (data) async {},
            queueListing: QueueListingUseCase(_MemoryQueue()),
            connectivity: GetConnectivityUseCase(network),
            userId: 'ana',
          ),
        ),
      ));
      await tester.tap(find.text('Books'));
      await tester.pump();
      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Gallery'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('listing-title')), 'Calculus');
      await tester.enterText(find.byKey(const Key('listing-description')), 'Barely used');
      await tester.enterText(find.byKey(const Key('smart-price-field')), '35000');

      await tester.tap(find.byKey(const Key('publish-listing')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('saved-offline-banner')), findsOneWidget);
      expect(find.text("Saved on your phone. We'll publish it as soon as you reconnect."), findsOneWidget);
      expect(find.byKey(const Key('published-banner')), findsNothing);
      await tester.pump(const Duration(seconds: 1)); // the screen leaves after the banner
      expect(app.screens, [AppScreen.sellerHub]);
    });
  });
}

class _Stats implements PriceStatsRepository {
  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) async =>
      const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
}

class _MemoryQueue extends PendingListingRepositoryImpl {
  _MemoryQueue() : super(OutboxStore(AppDatabase.withFactory(databaseFactoryFfi)));

  @override
  Future<PendingListing> queue({
    required String ownerId,
    required NewListingData data,
    required List<String> photoPaths,
  }) async =>
      PendingListing(id: 'q1', ownerId: ownerId, payload: const {}, photoPaths: photoPaths, createdAt: DateTime(2026, 10, 27));
}

class _NoApp implements AppViewModel {
  final screens = <AppScreen>[];

  @override
  void navigateTo(AppScreen screen) => screens.add(screen);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
