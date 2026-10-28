import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../core/isolates/photo_compressor.dart';
import '../model/data_sources/local/outbox_store.dart';
import '../model/dto/draft_models.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/new_listing_data.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/repositories/draft_repositories.dart';
import '../model/use_cases/classify_item_photo_use_case.dart';
import '../model/use_cases/price_estimator_use_case.dart';

/// Takes or picks a photo and returns its bytes; null if the user cancelled.
/// Throws when the camera or gallery cannot be used.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Creates the listing on the server. Throws [DataException] with a message to show.
typedef PublishListing = Future<void> Function(NewListingData data);

/// MVVM: the ViewModel of the "sell an item" screen (Smart Listing).
///
/// Holds everything the screen shows (category and condition, the optional photos, the price
/// estimate, the publishing state) and is the only code that talks to the use cases.
/// The View just renders these properties and forwards taps to the methods below.
class SmartListingViewModel extends ChangeNotifier {
  static const int maxPhotos = 3;

  final PriceEstimatorUseCase estimator;

  /// Camera / gallery and the photo classifier. Without them the photo features are
  /// unavailable and the user simply picks the category by hand.
  final PhotoPicker? pickPhoto;
  final ClassifyItemPhotoUseCase? classifyPhoto;

  /// Creates the listing. Without it publishing is unavailable.
  final PublishListing? publishListing;

  final SellDraftRepository? sellDraftRepository;
  final OutboxStore? outboxStore;
  final String? currentUserId;

  SmartListingViewModel({
    required this.estimator,
    this.pickPhoto,
    this.classifyPhoto,
    this.publishListing,
    this.sellDraftRepository,
    this.outboxStore,
    this.currentUserId,
  });

  String? _selectedCategory;
  String? _selectedCondition;
  PriceEstimate? _estimate;
  bool _isLoading = false;
  String? _errorMessage;

  final List<PendingImage> _photos = [];
  int _photoCounter = 0;
  bool _isPickingPhoto = false;
  bool _isScanningPhoto = false;
  String? _detectedCategory;
  String? _photoMessage;

  bool _isPublishing = false;
  bool _published = false;
  bool _publishedOffline = false;
  String? _publishError;

  int _scan = 0; // lets a photo scan that finishes late be ignored
  int _request = 0; // lets an answer that arrives late be ignored
  bool _disposed = false;
  Timer? _draftTimer;

  // ── Category and condition ────────────────────────────────────────────────

  /// Enum name of the chosen category (e.g. `BOOKS`), or null before choosing.
  String? get selectedCategory => _selectedCategory;

  /// Enum name of the chosen condition (e.g. `GOOD`), or null before choosing.
  String? get selectedCondition => _selectedCondition;

  // ── Price estimate ────────────────────────────────────────────────────────

  /// Median of comparable sales, or the heuristic price. Null until estimated.
  double? get suggestedPrice => _estimate?.suggestedPrice;
  double? get p25 => _estimate?.p25;
  double? get p75 => _estimate?.p75;

  /// Completed sales behind the estimate; 0 for a heuristic one.
  int get sampleSize => _estimate?.sampleSize ?? 0;

  /// True when the estimate comes from the local formula, not from real sales.
  bool get isFallback => _estimate?.isHeuristic ?? false;

  /// Why the estimate is a fallback (no connection vs. too few sales); null if not.
  PriceEstimateSource? get source => _estimate?.source;

  bool get hasEstimate => _estimate != null;

  /// Where the estimate comes from, ready to show under the price.
  String get estimateSourceLabel {
    switch (source) {
      case PriceEstimateSource.realSales:
        final n = sampleSize;
        return 'Based on $n real sale${n == 1 ? '' : 's'}';
      case PriceEstimateSource.lowSampleHeuristic:
        return 'Heuristic estimate, not enough sales yet';
      case PriceEstimateSource.offlineHeuristic:
      case null:
        return 'Heuristic estimate, no connection to sales data';
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Both choices are made, so a price can be estimated.
  bool get canEstimate => _selectedCategory != null && _selectedCondition != null && !_isLoading;

  // ── Photos (optional) ─────────────────────────────────────────────────────

  /// The photos taken or picked, in memory only. At least one is needed to publish.
  List<PendingImage> get photos => List.unmodifiable(_photos);

  /// The first photo, for code that only needs one.
  Uint8List? get imageBytes => _photos.isEmpty ? null : _photos.first.bytes;

  bool get canAddPhoto => _photos.length < maxPhotos && !_isPickingPhoto && !_isScanningPhoto;

  bool get isScanningPhoto => _isScanningPhoto;

  /// Category the photo scan recognised (enum name), or null if none.
  String? get detectedCategory => _detectedCategory;

  /// Something to tell the user about the photo (permission, nothing recognised), or null.
  String? get photoMessage => _photoMessage;

  /// A photo is there to classify and nothing else is using the vision service.
  bool get canDetectCategory =>
      _photos.isNotEmpty && classifyPhoto != null && !_isScanningPhoto && !_isPickingPhoto;

  // ── Publishing ────────────────────────────────────────────────────────────

  bool get isPublishing => _isPublishing;
  bool get published => _published;
  bool get publishedOffline => _publishedOffline;
  String? get publishError => _publishError;

  // ── Intents from the View ─────────────────────────────────────────────────

  void setCategory(String category) {
    if (!MaterialCategoryEnum.values.any((c) => c.name == category)) return;
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    _discardEstimate();
  }

  void setCondition(String condition) {
    if (!MaterialConditionEnum.values.any((c) => c.name == condition)) return;
    if (condition == _selectedCondition) return;
    _selectedCondition = condition;
    _discardEstimate();
  }

  /// Estimates a fair price for the chosen category and condition. Never throws: whatever
  /// goes wrong ends up in [errorMessage] or as a heuristic estimate ([isFallback]).
  Future<void> estimatePrice() async {
    if (!canEstimate) return;
    final category = MaterialCategoryEnum.values.byName(_selectedCategory!);
    final condition = MaterialConditionEnum.values.byName(_selectedCondition!);
    final request = ++_request;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    PriceEstimate? estimate;
    String? error;
    try {
      estimate = await estimator.execute(category: category, condition: condition);
    } catch (_) {
      error = 'Could not estimate a price. Please try again.';
    }

    if (_disposed || request != _request) return;
    _estimate = estimate;
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  /// Takes ([ImageSource.camera]) or picks ([ImageSource.gallery]) a photo and adds it.
  /// Never throws: a denied permission becomes [photoMessage].
  Future<void> addPhoto(ImageSource source) async {
    final pick = pickPhoto;
    if (pick == null || !canAddPhoto) return;
    final scan = _scan;

    _isPickingPhoto = true;
    _photoMessage = null;
    notifyListeners();

    Uint8List? bytes;
    String? message;
    try {
      bytes = await pick(source);
    } catch (_) {
      message = 'Could not access the camera or gallery. Check app permissions.';
    }

    if (_disposed || scan != _scan) return;
    _isPickingPhoto = false;
    _photoMessage = message;
    if (bytes != null) {
      final compressed = await PhotoCompressor.compressBytes(bytes);
      _photos.add(PendingImage(bytes: Uint8List.fromList(compressed), filename: 'photo-${++_photoCounter}.jpg'));
    }
    notifyListeners();
  }

  void removePhoto(int index) {
    if (index < 0 || index >= _photos.length || _isScanningPhoto) return;
    _photos.removeAt(index);
    if (_photos.isEmpty) {
      _detectedCategory = null;
      _photoMessage = null;
    }
    notifyListeners();
  }

  /// Asks the external vision service which category the first photo shows. A recognised
  /// category is selected and the price estimated again; otherwise the user picks by hand.
  /// Never throws.
  Future<void> detectCategoryFromPhoto() async {
    final classify = classifyPhoto;
    if (classify == null || !canDetectCategory) return;
    final scan = ++_scan;

    _isScanningPhoto = true;
    _photoMessage = null;
    notifyListeners();

    final category = await classify.execute(_photos.first.bytes);

    if (_disposed || scan != _scan) return;
    _isScanningPhoto = false;
    _detectedCategory = category?.name;
    _photoMessage = category == null ? "Couldn't recognise the item. Choose its category below." : null;
    if (category != null && category.name != _selectedCategory) {
      _selectedCategory = category.name;
      _discardEstimate(); // also notifies
    } else {
      notifyListeners();
    }
    // A new category (or the same one confirmed) means the price should be worked out again.
    if (category != null && _selectedCondition != null) await estimatePrice();
  }

  /// Adds a photo and, if one was added, detects the category from it.
  Future<void> scanItemFromImage(ImageSource source) async {
    if (_isScanningPhoto || _isPickingPhoto) return;
    final before = _photos.length;
    await addPhoto(source);
    if (_photos.length > before) await detectCategoryFromPhoto();
  }

  // ── Draft management ──────────────────────────────────────────────────────

  void debouncedSaveDraft({
    required String title,
    required String description,
    String courseCode = '',
    required String price,
  }) {
    final userId = currentUserId;
    if (sellDraftRepository == null || userId == null || userId.isEmpty) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      saveDraft(
        title: title,
        description: description,
        courseCode: courseCode,
        price: price,
      );
    });
  }

  Future<void> saveDraft({
    required String title,
    required String description,
    String courseCode = '',
    required String price,
  }) async {
    final userId = currentUserId;
    if (sellDraftRepository == null || userId == null || userId.isEmpty) return;
    final draft = SellDraft(
      title: title,
      description: description,
      courseCode: courseCode.isEmpty ? null : courseCode,
      price: double.tryParse(price.trim().replaceAll(',', '.')),
      category: _selectedCategory != null
          ? MaterialCategoryEnum.values.where((c) => c.name == _selectedCategory).firstOrNull
          : null,
      condition: _selectedCondition != null
          ? MaterialConditionEnum.values.where((c) => c.name == _selectedCondition).firstOrNull
          : null,
    );
    await sellDraftRepository!.save(userId: userId, draft: draft);
  }

  Future<SellDraft?> loadDraft() async {
    final userId = currentUserId;
    if (sellDraftRepository == null || userId == null || userId.isEmpty) return null;
    final draft = await sellDraftRepository!.load(userId: userId);
    if (draft != null && !draft.isEmpty) {
      if (draft.category != null && _selectedCategory == null) {
        _selectedCategory = draft.category!.name;
      }
      if (draft.condition != null && _selectedCondition == null) {
        _selectedCondition = draft.condition!.name;
      }
      notifyListeners();
      return draft;
    }
    return null;
  }

  Future<void> clearDraft() async {
    _draftTimer?.cancel();
    final userId = currentUserId;
    if (sellDraftRepository == null || userId == null || userId.isEmpty) return;
    await sellDraftRepository!.clear(userId: userId);
  }

  /// Validates the form and creates the listing. Returns true when it was published; otherwise
  /// [publishError] says why. Needs at least one photo; the price can be typed by hand, the
  /// estimate is only an optional help. Never throws.
  Future<bool> publish({
    required String title,
    required String description,
    String courseCode = '',
    required String price,
  }) async {
    final publisher = publishListing;
    if (_isPublishing || _published) return false;

    final amount = double.tryParse(price.trim().replaceAll(',', '.'));
    final problem = _selectedCategory == null
        ? 'Choose a category.'
        : _selectedCondition == null
            ? 'Choose a condition.'
            : _photos.isEmpty
                ? 'Please add at least one photo of the item'
                : title.trim().isEmpty
                    ? 'Add a title.'
                    : description.trim().isEmpty
                        ? 'Add a description.'
                        : (amount == null || amount <= 0)
                            ? 'Enter a valid price.'
                            : null;
    if (problem != null) {
      _publishError = problem;
      notifyListeners();
      return false;
    }

    _isPublishing = true;
    _publishError = null;
    _publishedOffline = false;
    notifyListeners();

    String? error;
    try {
      if (publisher != null) {
        await publisher(NewListingData(
          title: title,
          description: description,
          courseCode: courseCode,
          price: amount!,
          condition: MaterialConditionEnum.values.byName(_selectedCondition!),
          category: MaterialCategoryEnum.values.byName(_selectedCategory!),
          images: List.of(_photos),
        ));
      } else {
        throw const NoConnectionException();
      }
    } on NoConnectionException {
      // Offline fallback: compress photos in isolate, save files, and queue in OutboxStore
      final userId = currentUserId;
      if (outboxStore != null && userId != null && userId.isNotEmpty) {
        try {
          final photoPaths = <String>[];
          final tempDir = Directory.systemTemp;
          for (var i = 0; i < _photos.length; i++) {
            final compressed = await PhotoCompressor.compressBytes(_photos[i].bytes);
            final filePath = '${tempDir.path}/pending_photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            final file = File(filePath);
            await file.writeAsBytes(compressed, flush: true);
            photoPaths.add(filePath);
          }

          await outboxStore!.enqueueListing(
            ownerId: userId,
            payload: {
              'title': title.trim(),
              'description': description.trim(),
              if (courseCode.trim().isNotEmpty) 'courseCode': courseCode.trim(),
              'price': amount!.toStringAsFixed(2),
              'condition': _selectedCondition!,
              'category': _selectedCategory!,
            },
            photoPaths: photoPaths,
          );
          _publishedOffline = true;
        } catch (e) {
          error = 'Could not save listing offline: $e';
        }
      } else {
        error = 'Publishing is not available offline right now.';
      }
    } on DataException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unexpected error. Please try again.';
    }

    if (_disposed) return false;
    _isPublishing = false;
    _publishError = error;
    _published = error == null;
    if (_published) {
      await clearDraft();
    }
    notifyListeners();
    return _published;
  }

  /// Back to the initial state: nothing chosen, no photos, nothing estimated.
  void reset() {
    _scan++; // drop any photo scan still running
    _isScanningPhoto = false;
    _isPickingPhoto = false;
    _photos.clear();
    _detectedCategory = null;
    _photoMessage = null;
    _publishError = null;
    _published = false;
    _publishedOffline = false;
    _request++; // drop any answer still on its way
    _selectedCategory = null;
    _selectedCondition = null;
    _estimate = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// A new choice makes the current estimate (and any pending one) stale.
  void _discardEstimate() {
    _request++;
    _estimate = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
