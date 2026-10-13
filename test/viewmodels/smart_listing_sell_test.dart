import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/Domain/Entities/material_entity.dart';
import 'package:flutter_front_end/Domain/Entities/new_listing_data.dart';
import 'package:flutter_front_end/Domain/Entities/price_stats.dart';
import 'package:flutter_front_end/Domain/exceptions/data_exceptions.dart';
import 'package:flutter_front_end/Domain/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/Domain/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/Presentation/Screens/new_listing_smart_screen.dart';
import 'package:flutter_front_end/Presentation/State%20Management/app_state.dart';
import 'package:flutter_front_end/Presentation/ViewModels/smart_listing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _Stats implements PriceStatsRepository {
  Object? error;

  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) async {
    if (error != null) throw error!;
    return const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
  }
}

class _Backend {
  final published = <NewListingData>[];
  Object? error;
  Completer<void>? hang;

  Future<void> publish(NewListingData data) async {
    if (hang != null) await hang!.future;
    if (error != null) throw error!;
    published.add(data);
  }
}

class _NoApp implements AppState {
  final screens = <AppScreen>[];

  @override
  void navigateTo(AppScreen screen) => screens.add(screen);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Stats stats;
  late _Backend backend;
  late SmartListingViewModel vm;
  var picks = 0;

  setUp(() {
    stats = _Stats();
    backend = _Backend();
    picks = 0;
    vm = SmartListingViewModel(
      estimator: PriceEstimatorUseCase(repository: stats),
      pickPhoto: (source) async {
        picks++;
        return _png;
      },
      publishListing: backend.publish,
    );
  });

  tearDown(() => vm.dispose());

  Future<bool> publishValid({String price = '35000'}) async {
    vm.setCategory('BOOKS');
    vm.setCondition('GOOD');
    if (vm.photos.isEmpty) await vm.addPhoto(ImageSource.gallery);
    return vm.publish(title: ' Calculus ', description: 'Barely used', courseCode: 'MATE 1203', price: price);
  }

  group('photos are required, the price help is optional', () {
    test('cannot publish without a photo', () async {
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');

      final ok = await vm.publish(title: 'Calculus', description: 'Barely used', price: '35000');

      expect(ok, isFalse);
      expect(vm.publishError, 'Please add at least one photo of the item');
      expect(vm.published, isFalse);
      expect(backend.published, isEmpty);
    });

    test('with one photo it publishes, and the error goes away', () async {
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.publish(title: 'Calculus', description: 'Barely used', price: '35000');
      expect(vm.publishError, isNotNull);

      await vm.addPhoto(ImageSource.camera);
      final ok = await vm.publish(title: 'Calculus', description: 'Barely used', price: '35000');

      expect(ok, isTrue);
      expect(vm.publishError, isNull);
      expect(backend.published.single.images, hasLength(1));
    });

    test('removing the only photo makes publishing impossible again', () async {
      await vm.addPhoto(ImageSource.camera);
      vm.removePhoto(0);

      expect(await publishValid(), isTrue, reason: 'publishValid adds a photo when there is none');
      final again = SmartListingViewModel(
        estimator: PriceEstimatorUseCase(repository: stats),
        pickPhoto: (source) async => _png,
        publishListing: backend.publish,
      )
        ..setCategory('BOOKS')
        ..setCondition('GOOD');
      addTearDown(again.dispose);
      await again.addPhoto(ImageSource.camera);
      again.removePhoto(0);

      expect(await again.publish(title: 'x', description: 'y', price: '10'), isFalse);
      expect(again.publishError, 'Please add at least one photo of the item');
    });

    test('the price can be typed by hand without ever asking for a suggestion', () async {
      expect(vm.hasEstimate, isFalse);

      expect(await publishValid(price: '48000'), isTrue);

      expect(vm.hasEstimate, isFalse);
      expect(backend.published.single.price, 48000);
    });

    test('asking for a suggestion still works and does not change the typed price', () async {
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.estimatePrice();
      expect(vm.suggestedPrice, 30000);

      await vm.addPhoto(ImageSource.camera);
      expect(await vm.publish(title: 'x', description: 'y', price: '48000'), isTrue);

      expect(backend.published.single.price, 48000);
    });

    test('adds up to three photos with their own file names, then stops', () async {
      for (var i = 0; i < 5; i++) {
        await vm.addPhoto(ImageSource.gallery);
      }

      expect(vm.photos, hasLength(SmartListingViewModel.maxPhotos));
      expect(vm.photos.map((p) => p.filename).toSet(), hasLength(3));
      expect(vm.canAddPhoto, isFalse);
      expect(picks, 3);
    });

    test('removes a photo, freeing a slot', () async {
      await vm.addPhoto(ImageSource.camera);
      await vm.addPhoto(ImageSource.camera);

      vm.removePhoto(0);

      expect(vm.photos, hasLength(1));
      vm.removePhoto(7); // out of range: ignored
      expect(vm.photos, hasLength(1));
    });

    test('removing the last photo clears what was detected from it', () async {
      await vm.addPhoto(ImageSource.camera);

      vm.removePhoto(0);

      expect(vm.photos, isEmpty);
      expect(vm.detectedCategory, isNull);
      expect(vm.canDetectCategory, isFalse);
    });

    test('the photos travel with the listing', () async {
      await vm.addPhoto(ImageSource.camera);

      await publishValid();

      expect(backend.published.single.images, hasLength(1));
    });
  });

  group('publish', () {
    test('sends the trimmed-in data of the form', () async {
      expect(await publishValid(price: '35.500,5'.replaceAll('.', '')), isTrue);

      final data = backend.published.single;
      expect(data.category, MaterialCategoryEnum.BOOKS);
      expect(data.condition, MaterialConditionEnum.GOOD);
      expect(data.courseCode, 'MATE 1203');
      expect(data.price, 35500.5);
      expect(vm.published, isTrue);
      expect(vm.publishError, isNull);
      expect(vm.isPublishing, isFalse);
    });

    test('says what is missing and sends nothing', () async {
      expect(await vm.publish(title: 'x', description: 'y', price: '10'), isFalse);
      expect(vm.publishError, 'Choose a category.');

      vm.setCategory('BOOKS');
      await vm.publish(title: 'x', description: 'y', price: '10');
      expect(vm.publishError, 'Choose a condition.');

      vm.setCondition('GOOD');
      await vm.publish(title: 'x', description: 'y', price: '10');
      expect(vm.publishError, 'Please add at least one photo of the item');

      await vm.addPhoto(ImageSource.camera);
      await vm.publish(title: ' ', description: 'y', price: '10');
      expect(vm.publishError, 'Add a title.');
      await vm.publish(title: 'x', description: '', price: '10');
      expect(vm.publishError, 'Add a description.');
      await vm.publish(title: 'x', description: 'y', price: 'abc');
      expect(vm.publishError, 'Enter a valid price.');
      await vm.publish(title: 'x', description: 'y', price: '0');
      expect(vm.publishError, 'Enter a valid price.');

      expect(backend.published, isEmpty);
    });

    test('a server refusal is shown and the form stays editable', () async {
      backend.error = const DataException('Server said no');

      expect(await publishValid(), isFalse);

      expect(vm.publishError, 'Server said no');
      expect(vm.published, isFalse);
      expect(vm.isPublishing, isFalse);

      backend.error = null;
      expect(await vm.publish(title: 'a', description: 'b', price: '1000'), isTrue);
    });

    test('an unexpected failure never throws', () async {
      backend.error = StateError('boom');

      await expectLater(publishValid(), completion(isFalse));

      expect(vm.publishError, 'Unexpected error. Please try again.');
    });

    test('ignores a second tap while publishing', () async {
      backend.hang = Completer<void>();

      final first = publishValid();
      await Future<void>.delayed(Duration.zero);
      expect(vm.isPublishing, isTrue);
      expect(await vm.publish(title: 'x', description: 'y', price: '10'), isFalse);
      backend.hang!.complete();
      await first;

      expect(backend.published, hasLength(1));
    });

    test('without a publisher it explains instead of failing', () async {
      final bare = SmartListingViewModel(
        estimator: const PriceEstimatorUseCase(),
        pickPhoto: (source) async => _png,
      )
        ..setCategory('BOOKS')
        ..setCondition('GOOD');
      addTearDown(bare.dispose);
      await bare.addPhoto(ImageSource.camera);

      expect(await bare.publish(title: 'x', description: 'y', price: '10'), isFalse);
      expect(bare.publishError, contains('not available'));
    });
  });

  group('Sell screen', () {
    late _NoApp app;

    Future<void> pump(WidgetTester tester) async {
      app = _NoApp();
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: NewListingSmartScreen(
          appState: app,
          viewModelFactory: () => SmartListingViewModel(
            estimator: PriceEstimatorUseCase(repository: stats),
            pickPhoto: (source) async => _png,
            publishListing: backend.publish,
          ),
        ),
      ));
    }

    testWidgets('shows the sections in order: category, condition, photos, price, details', (tester) async {
      await pump(tester);

      double top(Finder f) => tester.getTopLeft(f).dy;
      final category = top(find.text('Category'));
      final condition = top(find.text('Condition'));
      final photos = top(find.text('Photos'));
      final suggest = top(find.text('Suggest Fair Price'));
      final title = top(find.byKey(const Key('listing-title')));
      final publish = top(find.byKey(const Key('publish-listing')));

      expect(category, lessThan(condition));
      expect(condition, lessThan(photos));
      expect(photos, lessThan(suggest));
      expect(suggest, lessThan(title));
      expect(title, lessThan(publish));
    });

    testWidgets('real estimate card fills the price field with one tap', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Books'));
      await tester.tap(find.text('Good'));
      await tester.pump();

      await tester.tap(find.text('Suggest Fair Price'));
      await tester.pumpAndSettle();

      expect(find.text('Based on 9 real sales'), findsOneWidget);
      expect(find.textContaining('\$30.000 COP'), findsOneWidget);

      await tester.tap(find.byKey(const Key('apply-suggested-price')));
      await tester.pump();

      final field = tester.widget<TextField>(find.descendant(
        of: find.byKey(const Key('smart-price-field')),
        matching: find.byType(TextField),
      ));
      expect(field.controller!.text, '30000');
    });

    testWidgets('photos show as removable previews', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('remove-photo-0')));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('publishes with a photo and a hand-typed price, then goes to the seller hub', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Books'));
      await tester.tap(find.text('Good'));
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('listing-title')), 'Calculus');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('listing-description')), 'Barely used');
      await tester.enterText(find.byKey(const Key('smart-price-field')), '35000');
      await tester.pump();

      await tester.tap(find.byKey(const Key('publish-listing')));
      await tester.pump();
      await tester.pump();

      expect(backend.published.single.images, hasLength(1));
      expect(backend.published.single.price, 35000);
      expect(find.byKey(const Key('published-banner')), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(app.screens, [AppScreen.sellerHub]);
    });

    testWidgets('without a photo the listing is not sent and the user is told why', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Books'));
      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('listing-title')), 'Calculus');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('listing-description')), 'Barely used');
      await tester.enterText(find.byKey(const Key('smart-price-field')), '35000');
      await tester.pump();

      await tester.tap(find.byKey(const Key('publish-listing')));
      await tester.pump();

      expect(find.text('Please add at least one photo of the item'), findsOneWidget);
      expect(backend.published, isEmpty);
      expect(find.byKey(const Key('published-banner')), findsNothing);
      expect(app.screens, isEmpty);
    });

    testWidgets('the suggestion button is only a help: nothing requires pressing it', (tester) async {
      await pump(tester);

      expect(find.byKey(const Key('estimate-price')), findsNothing);
      expect(find.text('Suggest Fair Price'), findsOneWidget);
      expect(find.textContaining('just type yours'), findsOneWidget);
    });

    testWidgets('an incomplete form shows what is missing', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('publish-listing')));
      await tester.pump();

      expect(find.text('Choose a category.'), findsOneWidget);
      expect(backend.published, isEmpty);
    });
  });
}
