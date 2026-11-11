// Recent searches kept in Hive (key/value database): store, repository rules and ViewModel.
import 'dart:io';

import 'package:flutter_front_end/model/data_sources/local/recent_searches_store.dart';
import 'package:flutter_front_end/model/repositories/impl/recent_searches_repository_impl.dart';
import 'package:flutter_front_end/model/use_cases/recent_searches_use_cases.dart';
import 'package:flutter_front_end/view_model/recent_searches_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

const _ana = 'user-ana';
const _leo = 'user-leo';

/// A store whose every call fails, like a box that cannot be opened.
class _BrokenStore extends RecentSearchesStore {
  @override
  Future<List<String>> read(String ownerId) async => throw const FileSystemException('disk error');

  @override
  Future<void> write(String ownerId, List<String> queries) async => throw const FileSystemException('disk error');
}

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('recent_searches_test');
    Hive.init(folder.path);
  });

  tearDown(() async {
    await Hive.close();
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  group('RecentSearchesStore (Hive)', () {
    test('nothing saved reads as an empty list', () async {
      expect(await RecentSearchesStore().read(_ana), isEmpty);
    });

    test('what is written is read back, per user', () async {
      final store = RecentSearchesStore();

      await store.write(_ana, ['calculus', 'physics']);
      await store.write(_leo, ['chemistry']);

      expect(await store.read(_ana), ['calculus', 'physics']);
      expect(await store.read(_leo), ['chemistry']);
    });

    test('the searches are still there after the box is closed and opened again (app restart)', () async {
      await RecentSearchesStore().write(_ana, ['calculus']);
      await Hive.close();

      expect(await RecentSearchesStore().read(_ana), ['calculus']);
    });

    test('writing an empty list removes the key', () async {
      final store = RecentSearchesStore();
      await store.write(_ana, ['calculus']);

      await store.write(_ana, const []);

      expect(await store.read(_ana), isEmpty);
      expect((await Hive.openBox<dynamic>(RecentSearchesStore.boxName)).containsKey(_ana), isFalse);
    });
  });

  group('RecentSearchesRepositoryImpl', () {
    late RecentSearchesRepositoryImpl repository;

    setUp(() => repository = RecentSearchesRepositoryImpl(RecentSearchesStore()));

    test('the latest search comes first', () async {
      await repository.add(_ana, 'calculus');
      final list = await repository.add(_ana, 'physics');

      expect(list, ['physics', 'calculus']);
      expect(await repository.getAll(_ana), ['physics', 'calculus']);
    });

    test('searching again (ignoring case and spaces) moves it to the front without a duplicate', () async {
      await repository.add(_ana, 'calculus');
      await repository.add(_ana, 'physics');

      final list = await repository.add(_ana, '  CALCULUS ');

      expect(list, ['CALCULUS', 'physics']);
    });

    test('a blank or one-letter query is not saved', () async {
      await repository.add(_ana, 'calculus');

      expect(await repository.add(_ana, '   '), ['calculus']);
      expect(await repository.add(_ana, 'a'), ['calculus']);
    });

    test('only the latest ${RecentSearchesRepositoryImpl.maxSearches} are kept', () async {
      for (var i = 1; i <= RecentSearchesRepositoryImpl.maxSearches + 3; i++) {
        await repository.add(_ana, 'query $i');
      }

      final list = await repository.getAll(_ana);

      expect(list.length, RecentSearchesRepositoryImpl.maxSearches);
      expect(list.first, 'query ${RecentSearchesRepositoryImpl.maxSearches + 3}');
      expect(list, isNot(contains('query 1')));
    });

    test('each user has their own list', () async {
      await repository.add(_ana, 'calculus');
      await repository.add(_leo, 'chemistry');

      expect(await repository.getAll(_ana), ['calculus']);
      expect(await repository.getAll(_leo), ['chemistry']);
    });

    test('remove forgets one search and clear forgets all of them', () async {
      await repository.add(_ana, 'calculus');
      await repository.add(_ana, 'physics');

      expect(await repository.remove(_ana, 'Calculus'), ['physics']);

      await repository.clear(_ana);
      expect(await repository.getAll(_ana), isEmpty);
    });

    test('a storage error never reaches the user: reads are empty and writes keep the old list', () async {
      final broken = RecentSearchesRepositoryImpl(_BrokenStore());

      expect(await broken.getAll(_ana), isEmpty);
      expect(await broken.add(_ana, 'calculus'), isEmpty);
      await broken.clear(_ana);
    });
  });

  group('RecentSearchesViewModel', () {
    late RecentSearchesViewModel vm;

    setUp(() {
      final repository = RecentSearchesRepositoryImpl(RecentSearchesStore());
      vm = RecentSearchesViewModel(
        getRecent: GetRecentSearchesUseCase(repository),
        saveRecent: SaveRecentSearchUseCase(repository),
        removeRecent: RemoveRecentSearchUseCase(repository),
        clearRecent: ClearRecentSearchesUseCase(repository),
      );
    });

    tearDown(() => vm.dispose());

    test('load shows what the user searched before', () async {
      await RecentSearchesStore().write(_ana, ['calculus']);

      await vm.load(_ana);

      expect(vm.searches, ['calculus']);
    });

    test('record, forget and clearAll update the list and notify', () async {
      await vm.load(_ana);
      var notified = 0;
      vm.addListener(() => notified++);

      await vm.record('calculus');
      await vm.record('physics');
      expect(vm.searches, ['physics', 'calculus']);

      await vm.forget('physics');
      expect(vm.searches, ['calculus']);

      await vm.clearAll();
      expect(vm.searches, isEmpty);
      expect(notified, greaterThanOrEqualTo(4));
    });

    test('what is recorded is saved on the phone', () async {
      await vm.load(_ana);

      await vm.record('calculus');

      expect(await RecentSearchesStore().read(_ana), ['calculus']);
    });

    test('changing user drops the other user\'s searches and shows the new one\'s', () async {
      await RecentSearchesStore().write(_ana, ['calculus']);
      await RecentSearchesStore().write(_leo, ['chemistry']);

      await vm.load(_ana);
      await vm.load(_leo);

      expect(vm.searches, ['chemistry']);
    });

    test('nobody signed in: nothing is shown and nothing is saved', () async {
      await vm.load(null);
      await vm.record('calculus');

      expect(vm.searches, isEmpty);
      expect(await RecentSearchesStore().read(_ana), isEmpty);
    });
  });
}
