import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/model/entities/material_entity.dart';
import 'package:flutter_front_end/model/entities/price_stats.dart';
import 'package:flutter_front_end/model/repositories/item_photo_classifier.dart';
import 'package:flutter_front_end/model/repositories/price_stats_repository.dart';
import 'package:flutter_front_end/model/use_cases/classify_item_photo_use_case.dart';
import 'package:flutter_front_end/model/use_cases/price_estimator_use_case.dart';
import 'package:flutter_front_end/view/screens/new_listing_smart_screen.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/smart_listing_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

// A 1x1 transparent PNG, so Image.memory has something valid to decode.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _FakeStats implements PriceStatsRepository {
  PriceStats? stats = const PriceStats(sampleSize: 9, p25: 20000, median: 30000, p75: 42000);
  int calls = 0;
  String? lastCategory;

  @override
  Future<PriceStats> getPriceStats({required String category, required String condition}) async {
    calls++;
    lastCategory = category;
    return stats!;
  }
}

class _FakeClassifier implements ItemPhotoClassifier {
  MaterialCategoryEnum? answer = MaterialCategoryEnum.CALCULATORS;
  Completer<MaterialCategoryEnum?>? pending;
  int calls = 0;

  @override
  Future<MaterialCategoryEnum?> classify(Uint8List imageBytes) {
    calls++;
    return pending?.future ?? Future.value(answer);
  }
}

class _FakeCamera {
  Uint8List? photo = _png;
  Object? error;
  final sources = <ImageSource>[];

  Future<Uint8List?> pick(ImageSource source) async {
    sources.add(source);
    if (error != null) throw error!;
    return photo;
  }
}

void main() {
  late _FakeStats stats;
  late _FakeClassifier classifier;
  late _FakeCamera camera;
  late SmartListingViewModel vm;

  setUp(() {
    stats = _FakeStats();
    classifier = _FakeClassifier();
    camera = _FakeCamera();
    vm = SmartListingViewModel(
      estimator: PriceEstimatorUseCase(repository: stats),
      pickPhoto: camera.pick,
      classifyPhoto: ClassifyItemPhotoUseCase(classifier),
    );
  });

  tearDown(() => vm.dispose());

  group('scanItemFromImage', () {
    test('starts with no photo and nothing detected', () {
      expect(vm.imageBytes, isNull);
      expect(vm.isScanningPhoto, isFalse);
      expect(vm.detectedCategory, isNull);
      expect(vm.photoMessage, isNull);
    });

    test('takes the photo with the requested source', () async {
      await vm.scanItemFromImage(ImageSource.camera);
      await vm.scanItemFromImage(ImageSource.gallery);

      expect(camera.sources, [ImageSource.camera, ImageSource.gallery]);
    });

    test('a recognised category is selected and shown, with the photo kept', () async {
      final states = <bool>[];
      vm.addListener(() => states.add(vm.isScanningPhoto));

      await vm.scanItemFromImage(ImageSource.camera);

      expect(states, contains(true));
      expect(vm.isScanningPhoto, isFalse);
      expect(vm.detectedCategory, 'CALCULATORS');
      expect(vm.selectedCategory, 'CALCULATORS');
      expect(vm.imageBytes, _png);
      expect(vm.photoMessage, isNull);
    });

    test('with a condition already chosen, the price is estimated again for the new category', () async {
      vm.setCategory('BOOKS');
      vm.setCondition('GOOD');
      await vm.estimatePrice();
      expect(stats.lastCategory, 'BOOKS');
      final before = stats.calls;

      await vm.scanItemFromImage(ImageSource.gallery);

      expect(stats.calls, before + 1);
      expect(stats.lastCategory, 'CALCULATORS');
      expect(vm.suggestedPrice, 30000);
      expect(vm.isLoading, isFalse);
    });

    test('without a condition it only selects the category', () async {
      await vm.scanItemFromImage(ImageSource.camera);

      expect(stats.calls, 0);
      expect(vm.hasEstimate, isFalse);
    });

    test('an unrecognised photo keeps the photo and tells the user to choose by hand', () async {
      vm.setCategory('BOOKS');
      classifier.answer = null; // no connection, timeout, HTTP error...

      await vm.scanItemFromImage(ImageSource.camera);

      expect(vm.imageBytes, _png);
      expect(vm.detectedCategory, isNull);
      expect(vm.selectedCategory, 'BOOKS', reason: 'the manual choice is untouched');
      expect(vm.photoMessage, contains('Choose'));
      expect(vm.isScanningPhoto, isFalse);
    });

    test('cancelling the camera changes nothing', () async {
      camera.photo = null;

      await vm.scanItemFromImage(ImageSource.camera);

      expect(vm.imageBytes, isNull);
      expect(vm.photoMessage, isNull);
      expect(classifier.calls, 0);
      expect(vm.isScanningPhoto, isFalse);
    });

    test('a denied permission becomes a message, not an exception', () async {
      camera.error = Exception('camera_access_denied');

      await expectLater(vm.scanItemFromImage(ImageSource.camera), completes);

      expect(vm.photoMessage, contains('permissions'));
      expect(vm.isScanningPhoto, isFalse);
      expect(classifier.calls, 0);
    });

    test('ignores a second scan while one is running', () async {
      classifier.pending = Completer<MaterialCategoryEnum?>();

      final first = vm.scanItemFromImage(ImageSource.camera);
      await Future<void>.delayed(Duration.zero);
      await vm.scanItemFromImage(ImageSource.camera);
      classifier.pending!.complete(MaterialCategoryEnum.FURNITURE);
      await first;

      expect(camera.sources, hasLength(1));
      expect(vm.selectedCategory, 'FURNITURE');
    });

    test('reset while scanning drops the late answer', () async {
      classifier.pending = Completer<MaterialCategoryEnum?>();

      final running = vm.scanItemFromImage(ImageSource.camera);
      await Future<void>.delayed(Duration.zero);
      vm.reset();
      classifier.pending!.complete(MaterialCategoryEnum.FURNITURE);
      await running;

      expect(vm.selectedCategory, isNull);
      expect(vm.imageBytes, isNull);
      expect(vm.isScanningPhoto, isFalse);
    });

    test('reset clears the photo and the detection', () async {
      await vm.scanItemFromImage(ImageSource.camera);

      vm.reset();

      expect(vm.imageBytes, isNull);
      expect(vm.detectedCategory, isNull);
      expect(vm.photoMessage, isNull);
    });

    test('does nothing when no camera or classifier was given', () async {
      final bare = SmartListingViewModel(estimator: const PriceEstimatorUseCase());
      addTearDown(bare.dispose);

      await expectLater(bare.scanItemFromImage(ImageSource.camera), completes);

      expect(bare.isScanningPhoto, isFalse);
    });

    test('a scan that finishes after dispose does not notify', () async {
      final model = SmartListingViewModel(
        estimator: PriceEstimatorUseCase(repository: stats),
        pickPhoto: camera.pick,
        classifyPhoto: ClassifyItemPhotoUseCase(classifier),
      );
      classifier.pending = Completer<MaterialCategoryEnum?>();

      final running = model.scanItemFromImage(ImageSource.camera);
      await Future<void>.delayed(Duration.zero);
      model.dispose();
      classifier.pending!.complete(MaterialCategoryEnum.BOOKS);

      await expectLater(running, completes);
    });
  });

  group('Sell screen photo detection', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: NewListingSmartScreen(
          appState: _NoApp(),
          viewModelFactory: () => SmartListingViewModel(
            estimator: PriceEstimatorUseCase(repository: stats),
            pickPhoto: camera.pick,
            classifyPhoto: ClassifyItemPhotoUseCase(classifier),
          ),
        ),
      ));
    }

    testWidgets('Camera only adds the photo; detection is a separate, discreet button', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('detect-category')), findsNothing);

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(camera.sources, [ImageSource.camera]);
      expect(classifier.calls, 0);
      expect(find.byKey(const Key('photo-previews')), findsOneWidget);
      expect(find.text('Auto-detect category from photo'), findsOneWidget);
    });

    testWidgets('Auto-detect shows progress, then the detected category', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      classifier.pending = Completer<MaterialCategoryEnum?>();

      await tester.tap(find.byKey(const Key('detect-category')));
      await tester.pump();

      expect(find.byKey(const Key('scan-progress')), findsOneWidget);

      classifier.pending!.complete(MaterialCategoryEnum.LAB_EQUIPMENT);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan-progress')), findsNothing);
      expect(find.text('Detected: Lab Equipment'), findsOneWidget);
      expect(camera.sources, [ImageSource.gallery]);
    });

    testWidgets('a failed detection leaves the screen usable with a hint', (tester) async {
      await pump(tester);
      classifier.answer = null;
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('detect-category')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo-scan-result')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(MaterialCategoryEnum.BOOKS.displayName));
      await tester.pump();
      expect(find.byKey(const Key('photo-scan-result')), findsOneWidget);
    });

    testWidgets('a denied camera permission shows a message, not a crash', (tester) async {
      await pump(tester);
      camera.error = Exception('camera_access_denied');

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(find.textContaining('permissions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _NoApp implements AppViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
