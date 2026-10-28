import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/model/data_sources/local/draft_photo_store.dart';
import 'package:flutter_front_end/model/data_sources/local/draft_store.dart';
import 'package:flutter_front_end/model/entities/listing_draft.dart';
import 'package:flutter_front_end/model/entities/new_listing_data.dart';
import 'package:flutter_front_end/model/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/model/repositories/draft_repositories.dart';
import 'package:flutter_front_end/model/repositories/impl/draft_repositories_impl.dart';
import 'package:flutter_front_end/model/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/model/entities/price_stats.dart';
import 'package:flutter_front_end/model/use_cases/listing_draft_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/view/screens/new_listing_smart_screen.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/smart_listing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = 'user-1';
final _photo = Uint8List.fromList(List.generate(64, (i) => i));

class _Stats implements PriceStatsRepository {
  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) async =>
      const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
}

/// Keeps the draft in memory and records what was done to it.
class _MemoryDrafts implements ListingDraftRepository {
  ListingDraft? stored;
  final saves = <ListingDraft>[];
  var clears = 0;

  @override
  Future<ListingDraft?> load(String userId) async => stored;

  @override
  Future<void> save(String userId, ListingDraft draft) async {
    saves.add(draft);
    stored = draft;
  }

  @override
  Future<void> clear(String userId) async {
    clears++;
    stored = null;
  }
}

class _NoApp implements AppViewModel {
  final screens = <AppScreen>[];

  @override
  void navigateTo(AppScreen screen) => screens.add(screen);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SmartListingViewModel _viewModel(ListingDraftRepository drafts, {PublishListing? publish}) => SmartListingViewModel(
      estimator: PriceEstimatorUseCase(repository: _Stats()),
      pickPhoto: (source) async => _photo,
      publishListing: publish,
      userId: _user,
      loadDraft: LoadListingDraftUseCase(drafts),
      saveDraft: SaveListingDraftUseCase(drafts),
      clearDraft: ClearListingDraftUseCase(drafts),
    );

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late _MemoryDrafts drafts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    drafts = _MemoryDrafts();
  });

  group('auto-save (debounce 400 ms)', () {
    test('only the last state is written, 0.4 s after the last change', () async {
      final vm = _viewModel(drafts);

      vm.onFormChanged(title: 'C', description: '', courseCode: '', price: '');
      await _wait(250);
      vm.onFormChanged(title: 'Calculus', description: '', courseCode: '', price: '');
      await _wait(250); // 500 ms since the first change, 250 since the last
      expect(drafts.saves, isEmpty);

      await _wait(250);
      expect(drafts.saves, hasLength(1));
      expect(drafts.saves.single.title, 'Calculus');
      vm.dispose();
    });

    test('category, condition and photos also start the timer', () async {
      final vm = _viewModel(drafts);

      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.addPhoto(ImageSource.gallery);
      await _wait(500);

      expect(drafts.saves, hasLength(1));
      final saved = drafts.saves.single;
      expect(saved.category, 'BOOKS');
      expect(saved.condition, 'GOOD');
      expect(saved.photos.single.bytes, _photo);
      vm.dispose();
    });

    test('leaving the screen writes a change that was still waiting for its timer', () async {
      final vm = _viewModel(drafts);

      vm.onFormChanged(title: 'Calculus', description: '', courseCode: '', price: '');
      vm.dispose();
      await _wait(10);

      expect(drafts.saves.single.title, 'Calculus');
    });

    test('without a user nothing is saved', () async {
      final vm = SmartListingViewModel(estimator: PriceEstimatorUseCase(repository: _Stats()));

      vm.onFormChanged(title: 'Calculus', description: '', courseCode: '', price: '');
      await _wait(500);

      expect(vm.draftEnabled, isFalse);
      expect(await vm.restoreDraft(), isNull);
      vm.dispose();
    });
  });

  group('restoring', () {
    final saved = ListingDraft(
      title: 'Calculus',
      description: 'Barely used',
      courseCode: 'MATE 1203',
      price: '35000',
      condition: 'GOOD',
      category: 'BOOKS',
      photos: [PendingImage(bytes: _photo, filename: 'photo-2.jpg')],
    );

    test('puts back the choices and photos, and returns the text for the fields', () async {
      drafts.stored = saved;
      final vm = _viewModel(drafts);

      final draft = await vm.restoreDraft();

      expect(draft!.title, 'Calculus');
      expect(vm.selectedCategory, 'BOOKS');
      expect(vm.selectedCondition, 'GOOD');
      expect(vm.photos.single.bytes, _photo);
      expect(vm.restoredDraft, isTrue);
      vm.dispose();
    });

    test('a photo added afterwards does not reuse a restored photo name', () async {
      drafts.stored = saved;
      final vm = _viewModel(drafts);
      await vm.restoreDraft();

      await vm.addPhoto(ImageSource.gallery);

      expect(vm.photos.map((p) => p.filename), ['photo-2.jpg', 'photo-3.jpg']);
      vm.dispose();
    });

    test('there is nothing to restore when no draft was saved', () async {
      final vm = _viewModel(drafts);

      expect(await vm.restoreDraft(), isNull);
      expect(vm.restoredDraft, isFalse);
      vm.dispose();
    });

    test('a form the user already started is not overwritten', () async {
      drafts.stored = saved;
      final vm = _viewModel(drafts)..setCategory('OTHER');

      expect(await vm.restoreDraft(), isNull);
      expect(vm.selectedCategory, 'OTHER');
      vm.dispose();
    });
  });

  group('cleaning up', () {
    Future<bool> publish(SmartListingViewModel vm) async {
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.addPhoto(ImageSource.gallery);
      return vm.publish(title: 'Calculus', description: 'Barely used', courseCode: '', price: '35000');
    }

    test('publishing (or queueing offline) deletes the draft and nothing is saved after', () async {
      final vm = _viewModel(drafts, publish: (data) async {});

      expect(await publish(vm), isTrue);
      await _wait(500);

      expect(drafts.clears, 1);
      expect(drafts.stored, isNull);
      expect(drafts.saves, isEmpty);
      vm.dispose();
    });

    test('a refused listing keeps the draft', () async {
      final vm = _viewModel(drafts, publish: (data) async => throw const ApiLikeError());

      expect(await publish(vm), isFalse);
      await _wait(500);

      expect(drafts.clears, 0);
      expect(drafts.saves.last.title, 'Calculus');
      vm.dispose();
    });

    test('discarding deletes the draft and cancels a save that was waiting', () async {
      final vm = _viewModel(drafts);
      vm.onFormChanged(title: 'Calculus', description: '', courseCode: '', price: '');

      await vm.discardDraft();
      await _wait(500);

      expect(drafts.clears, 1);
      expect(drafts.saves, isEmpty);
      vm.dispose();
    });

    test('hasUnpublishedWork tells whether leaving would lose something', () {
      final vm = _viewModel(drafts);
      expect(vm.hasUnpublishedWork, isFalse);

      vm.onFormChanged(title: ' ', description: '', courseCode: '', price: '');
      expect(vm.hasUnpublishedWork, isFalse);

      vm.onFormChanged(title: 'Calculus', description: '', courseCode: '', price: '');
      expect(vm.hasUnpublishedWork, isTrue);
      vm.dispose();
    });
  });

  group('on disk (shared_preferences + documents folder)', () {
    late Directory documents;
    late ListingDraftRepositoryImpl real;

    setUp(() {
      documents = Directory.systemTemp.createTempSync('listing_draft');
      real = ListingDraftRepositoryImpl(DraftStore(), DraftPhotoStore(() async => documents));
    });
    tearDown(() => documents.deleteSync(recursive: true));

    test('saves one JSON with the form and the local paths of the photos, and reads it back', () async {
      final vm = _viewModel(real);
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.addPhoto(ImageSource.gallery);
      vm.onFormChanged(title: 'Calculus', description: 'Barely used', courseCode: 'MATE 1203', price: '35000');
      await vm.flushDraft();

      final json = jsonDecode((await SharedPreferences.getInstance()).getString('listing_draft:$_user')!) as Map;
      expect(json['title'], 'Calculus');
      expect(json['description'], 'Barely used');
      expect(json['course'], 'MATE 1203');
      expect(json['price'], '35000');
      expect(json['condition'], 'GOOD');
      expect(json['category'], 'BOOKS');
      final path = (json['photoPaths'] as List).single as String;
      expect(File(path).readAsBytesSync(), _photo);

      final back = (await real.load(_user))!;
      expect(back.title, 'Calculus');
      expect(back.photos.single.bytes, _photo);
      vm.dispose();
    });

    test('removing a photo deletes its file', () async {
      final vm = _viewModel(real);
      await vm.addPhoto(ImageSource.gallery);
      await vm.flushDraft();
      expect(Directory('${documents.path}/listing_draft/$_user').listSync(), hasLength(1));

      vm.removePhoto(0);
      vm.setCategory('BOOKS');
      await vm.flushDraft();

      expect(Directory('${documents.path}/listing_draft/$_user').listSync(), isEmpty);
      vm.dispose();
    });

    test('publishing removes the stored JSON and the photo files', () async {
      final vm = _viewModel(real, publish: (data) async {});
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.addPhoto(ImageSource.gallery);
      await vm.flushDraft();

      expect(await vm.publish(title: 'Calculus', description: 'Barely used', price: '35000'), isTrue);
      await vm.discardDraft(); // waits for the cleanup that publish started

      expect((await SharedPreferences.getInstance()).getString('listing_draft:$_user'), isNull);
      expect(Directory('${documents.path}/listing_draft/$_user').existsSync(), isFalse);
      vm.dispose();
    });

    test('a draft whose photo file vanished still restores the rest', () async {
      final vm = _viewModel(real);
      vm.setCategory('BOOKS');
      await vm.addPhoto(ImageSource.gallery);
      await vm.flushDraft();
      Directory('${documents.path}/listing_draft/$_user').deleteSync(recursive: true);

      final back = (await real.load(_user))!;

      expect(back.category, 'BOOKS');
      expect(back.photos, isEmpty);
      vm.dispose();
    });

    test('a draft written in an unreadable shape is ignored', () async {
      SharedPreferences.setMockInitialValues({'listing_draft:$_user': '{"photoPaths": 5}'});

      expect(await real.load(_user), isNull);
    });
  });

  group('Sell screen', () {
    late _NoApp app;

    Future<void> pump(WidgetTester tester) async {
      app = _NoApp();
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: NewListingSmartScreen(appState: app, viewModelFactory: () => _viewModel(drafts)),
      ));
      await tester.pump();
    }

    testWidgets('restores the draft into the fields and says so', (tester) async {
      drafts.stored = const ListingDraft(
        title: 'Calculus',
        description: 'Barely used',
        courseCode: 'MATE 1203',
        price: '35000',
        category: 'BOOKS',
        condition: 'GOOD',
      );

      await pump(tester);

      expect(find.text('We restored the draft you left unfinished.'), findsOneWidget);
      expect(find.text('Calculus'), findsOneWidget);
      expect(find.text('Barely used'), findsOneWidget);
      expect(find.text('MATE 1203'), findsOneWidget);
      expect(find.text('35000'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('no draft, no message', (tester) async {
      await pump(tester);

      expect(find.text('We restored the draft you left unfinished.'), findsNothing);
    });

    testWidgets('typing is saved after 0.4 s', (tester) async {
      await pump(tester);

      await tester.enterText(find.byKey(const Key('listing-title')), 'Physics');
      await tester.pump(const Duration(milliseconds: 300));
      expect(drafts.saves, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));

      expect(drafts.saves.single.title, 'Physics');
    });

    testWidgets('leaving with a draft asks, and "Discard draft" deletes it', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('listing-title')), 'Physics');

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Leave this listing?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('discard-draft')));
      await tester.pumpAndSettle();

      expect(drafts.clears, 1);
      expect(drafts.stored, isNull);
      expect(app.screens, [AppScreen.home]);
    });

    testWidgets('"Keep draft" saves it right away and leaves', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('listing-title')), 'Physics');

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keep-draft')));
      await tester.pumpAndSettle();

      expect(drafts.stored!.title, 'Physics');
      expect(drafts.clears, 0);
      expect(app.screens, [AppScreen.home]);
    });

    testWidgets('closing the dialog stays on the screen', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('listing-title')), 'Physics');

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // the barrier
      await tester.pumpAndSettle();

      expect(app.screens, isEmpty);
      expect(find.text('Leave this listing?'), findsNothing);
    });

    testWidgets('an empty form leaves without asking', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Leave this listing?'), findsNothing);
      expect(app.screens, [AppScreen.home]);
    });
  });
}

class ApiLikeError extends DataException {
  const ApiLikeError() : super('The server refused it.');
}
