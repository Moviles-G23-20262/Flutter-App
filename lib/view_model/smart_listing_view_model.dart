import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:path/path.dart' as p;
import '../core/isolates/photo_compressor.dart';
import '../model/rules/client_id.dart';
import '../model/entities/listing_draft.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/new_listing_data.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/classify_item_photo_use_case.dart';
import '../model/use_cases/connectivity_use_cases.dart';
import '../model/use_cases/listing_draft_use_cases.dart';
import '../model/use_cases/pending_listing_use_cases.dart';
import '../model/use_cases/price_estimator_use_case.dart';
import '../model/use_cases/get_time_to_sell_use_case.dart';

/// Takes or picks a photo and returns its bytes; null if the user cancelled.
/// Throws when the camera or gallery cannot be used.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Creates the listing on the server. Throws [DataException] with a message to show, or its
/// subclass [NoConnectionException] when the server could not be reached.
typedef PublishListing = Future<void> Function(NewListingData data);

/// MVVM: the ViewModel of the "sell an item" screen (Smart Listing).
///
/// Holds everything the screen shows (category and condition, the optional photos, the price
/// estimate, the publishing state) and is the only code that talks to the use cases.
/// The View just renders these properties and forwards taps to the methods below.
///
/// What is entered is saved as a draft 0.4 s after the last change and restored when the screen
/// opens again; the draft is deleted once the listing is published or queued, or discarded.
class SmartListingViewModel extends ChangeNotifier {
  static const int maxPhotos = 3;
  static const Duration draftDelay = Duration(milliseconds: 400);

  /// Shown when the listing could not be sent and was kept on the phone.
  static const String savedOfflineMessage = "Saved on your phone. We'll publish it as soon as you reconnect.";

  final PriceEstimatorUseCase estimator;

  /// Camera / gallery and the photo classifier. Without them the photo features are
  /// unavailable and the user simply picks the category by hand.
  final PhotoPicker? pickPhoto;
  final ClassifyItemPhotoUseCase? classifyPhoto;

  /// Creates the listing. Without it publishing is unavailable.
  final PublishListing? publishListing;

  /// Shrinks the photos before they are uploaded or saved (in an isolate). Without it they go
  /// as they are.
  final PhotoCompressor? compressPhotos;

  /// Keeps the listing on the phone when it cannot be sent; the sync service publishes it later.
  /// Needs [userId]. Without it a failed connection is reported as an error.
  final QueueListingUseCase? queueListing;

  /// Tells whether the phone is online, so an offline publish is saved at once instead of
  /// waiting for a request to time out.
  final GetConnectivityUseCase? connectivity;

  /// Makes the client id of a listing (UUIDv4). Replaceable so tests can know it.
  final String Function() newListingId;

  /// The signed-in user the draft belongs to, and the draft use cases. Without them nothing is
  /// saved or restored.
  final String? userId;
  final LoadListingDraftUseCase? loadDraft;
  final SaveListingDraftUseCase? saveDraft;
  final ClearListingDraftUseCase? clearDraft;
  final GetTimeToSellUseCase? getTimeToSell;

  SmartListingViewModel({
    required this.estimator,
    this.pickPhoto,
    this.classifyPhoto,
    this.publishListing,
    this.compressPhotos,
    this.queueListing,
    this.connectivity,
    String Function()? newListingId,
    this.userId,
    this.loadDraft,
    this.saveDraft,
    this.clearDraft,
    this.getTimeToSell,
  }) : newListingId = newListingId ?? newClientId;

  String? _selectedCategory;
  String? _selectedCondition;
  PriceEstimate? _estimate;
  bool _isLoading = false;
  String? _errorMessage;
  double? _estimatedDaysToSell;

  final List<PendingImage> _photos = [];
  int _photoCounter = 0;
  bool _isPickingPhoto = false;
  bool _isScanningPhoto = false;
  String? _detectedCategory;
  String? _photoMessage;

  bool _isPublishing = false;
  bool _published = false;
  bool _savedOffline = false;

  /// The client id of the listing being published. It stays the same for every attempt of this
  /// form (online, retried after an error, or saved offline), so the server can tell they are
  /// one listing. A new form gets a new one.
  String? _listingClientId;
  String? _publishError;

  // The text lives in the View's controllers; they report it through [onFormChanged].
  String _title = '';
  String _description = '';
  String _courseCode = '';
  String _price = '';

  Timer? _draftTimer;

  /// Saves and deletes run one after the other, so a late save never undoes a delete.
  Future<void> _draftWork = Future.value();

  /// After a publish or a discard nothing more is saved.
  bool _draftClosed = false;
  bool _restoredDraft = false;

  int _scan = 0; // lets a photo scan that finishes late be ignored
  int _request = 0; // lets an answer that arrives late be ignored
  bool _disposed = false;

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
  double? get estimatedDaysToSell => _estimatedDaysToSell;

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

  /// Published = true and the listing is waiting on the phone ([savedOfflineMessage]), not live yet.
  bool get savedOffline => _savedOffline;
  String? get publishError => _publishError;

  // ── Intents from the View ─────────────────────────────────────────────────

  void setCategory(String category) {
    if (!MaterialCategoryEnum.values.any((c) => c.name == category)) return;
    if (category == _selectedCategory) return;
    _selectedCategory = category;
    _discardEstimate();
    _scheduleDraftSave();
  }

  void setCondition(String condition) {
    if (!MaterialConditionEnum.values.any((c) => c.name == condition)) return;
    if (condition == _selectedCondition) return;
    _selectedCondition = condition;
    _discardEstimate();
    _scheduleDraftSave();
  }

  /// The View reports the text of its fields whenever one changes.
  void onFormChanged({
    required String title,
    required String description,
    required String courseCode,
    required String price,
  }) {
    if (title == _title && description == _description && courseCode == _courseCode && price == _price) return;
    _title = title;
    _description = description;
    _courseCode = courseCode;
    _price = price;
    _scheduleDraftSave();
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
      if (getTimeToSell != null) {
        try {
          final insight = await getTimeToSell!.execute();
          _estimatedDaysToSell = insight.daysForCategory(category.name);
        } catch (_) {}
      }
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
      _photos.add(PendingImage(bytes: bytes, filename: 'photo-${++_photoCounter}.jpg'));
      _scheduleDraftSave();
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
    _scheduleDraftSave();
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
      _scheduleDraftSave();
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
    onFormChanged(title: title, description: description, courseCode: courseCode, price: price);

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
                        : publisher == null
                            ? 'Publishing is not available right now.'
                            : null;
    if (problem != null) {
      _publishError = problem;
      notifyListeners();
      return false;
    }

    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    String? error;
    var savedOffline = false;
    var compressedPaths = <String>[];
    try {
      // The photos are shrunk and saved on the phone first (in an isolate, so the screen keeps
      // drawing); they are what gets uploaded now or, offline, what waits in the queue.
      var images = List.of(_photos);
      final compress = compressPhotos;
      if (compress != null) {
        final compressed = await compress([for (final photo in _photos) photo.bytes]);
        compressedPaths = [for (final photo in compressed) photo.path];
        images = [for (final photo in compressed) PendingImage(bytes: photo.bytes, filename: p.basename(photo.path))];
      }
      final data = NewListingData(
        title: title,
        description: description,
        courseCode: courseCode,
        price: amount!,
        condition: MaterialConditionEnum.values.byName(_selectedCondition!),
        category: MaterialCategoryEnum.values.byName(_selectedCategory!),
        images: images,
        clientId: _listingClientId ??= newListingId(),
      );

      if (await _isOnline()) {
        try {
          await publisher!(data);
        } on NoConnectionException {
          await _saveOffline(data, compressedPaths);
          savedOffline = true;
        }
      } else {
        await _saveOffline(data, compressedPaths);
        savedOffline = true;
      }
    } on DataException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unexpected error. Please try again.';
    }
    // Published or refused: the compressed copies are not needed. Queued ones are kept.
    if (!savedOffline) await deleteCompressedPhotos(compressedPaths);

    if (_disposed) return false;
    _isPublishing = false;
    _publishError = error;
    _published = error == null;
    _savedOffline = error == null && savedOffline;
    // Published, or saved in the offline queue: either way the draft has done its job.
    if (_published) unawaited(discardDraft());
    notifyListeners();
    return _published;
  }

  Future<bool> _isOnline() async {
    final check = connectivity;
    if (check == null) return true;
    try {
      return await check.execute();
    } catch (_) {
      return true; // cannot tell: try the request
    }
  }

  /// Keeps the listing on the phone. Throws [NoConnectionException] when that is not possible
  /// (nobody signed in, or no queue), so the user gets the usual "can't reach the server".
  Future<void> _saveOffline(NewListingData data, List<String> photoPaths) async {
    final queue = queueListing;
    final owner = userId;
    if (queue == null || owner == null) throw const NoConnectionException();
    await queue.execute(ownerId: owner, data: data, photoPaths: photoPaths);
  }

  // ── Draft ─────────────────────────────────────────────────────────────────

  /// Whether a draft is being kept for this screen at all.
  bool get draftEnabled => userId != null && saveDraft != null;

  /// A saved draft was put back into the form.
  bool get restoredDraft => _restoredDraft;

  /// There is something entered that would be lost on leaving without a draft.
  bool get hasUnpublishedWork => !_published && !_currentDraft().isEmpty;

  /// Puts the saved draft back (category, condition, photos) and returns it so the View can fill
  /// its text fields; null when there is none. Call once when the screen opens. A form the user
  /// already started is left alone.
  Future<ListingDraft?> restoreDraft() async {
    final id = userId;
    final load = loadDraft;
    if (id == null || load == null) return null;
    final draft = await load.execute(id);
    if (draft == null || draft.isEmpty || _disposed || _draftClosed) return null;
    if (!_currentDraft().isEmpty) return null;

    _title = draft.title;
    _description = draft.description;
    _courseCode = draft.courseCode;
    _price = draft.price;
    _selectedCategory = draft.category;
    _selectedCondition = draft.condition;
    _photos
      ..clear()
      ..addAll(draft.photos.take(maxPhotos));
    // New photos must not reuse the names of the restored ones.
    for (final photo in _photos) {
      final number = int.tryParse(RegExp(r'\d+').firstMatch(photo.filename)?.group(0) ?? '') ?? 0;
      if (number > _photoCounter) _photoCounter = number;
    }
    _restoredDraft = true;
    _discardEstimate(); // also notifies
    return draft;
  }

  /// Writes a change still waiting for its timer now (e.g. before leaving the screen).
  Future<void> flushDraft() async {
    if (_draftTimer?.isActive ?? false) {
      _draftTimer!.cancel();
      await _saveDraft();
    }
    await _draftWork;
  }

  /// Deletes the draft and stops saving: the listing was published or queued, or the user
  /// threw the draft away.
  Future<void> discardDraft() {
    _draftClosed = true;
    _draftTimer?.cancel();
    final id = userId;
    final clear = clearDraft;
    if (id == null || clear == null) return Future.value();
    return _draftWork = _draftWork.then((_) => clear.execute(id)).catchError((Object _) {});
  }

  ListingDraft _currentDraft() => ListingDraft(
        title: _title,
        description: _description,
        courseCode: _courseCode,
        price: _price,
        condition: _selectedCondition,
        category: _selectedCategory,
        photos: List.of(_photos),
      );

  /// Debounce: every change restarts the timer, so only the last state is written.
  void _scheduleDraftSave() {
    if (!draftEnabled || _draftClosed || _disposed) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDelay, _saveDraft);
  }

  Future<void> _saveDraft() {
    final id = userId;
    final save = saveDraft;
    if (id == null || save == null || _draftClosed) return _draftWork;
    final draft = _currentDraft();
    return _draftWork = _draftWork.then((_) {
      if (!_draftClosed) return save.execute(id, draft);
    }).catchError((Object _) {});
  }

  /// Back to the initial state: nothing chosen, no photos, nothing estimated, no draft.
  void reset() {
    _title = _description = _courseCode = _price = '';
    unawaited(discardDraft());
    _draftClosed = false; // the next form can be saved again
    _scan++; // drop any photo scan still running
    _isScanningPhoto = false;
    _isPickingPhoto = false;
    _photos.clear();
    _detectedCategory = null;
    _photoMessage = null;
    _publishError = null;
    _published = false;
    _savedOffline = false;
    _listingClientId = null;
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

  /// A change still waiting for its timer is written now, so leaving the screen loses nothing.
  @override
  void dispose() {
    if (_draftTimer?.isActive ?? false) {
      _draftTimer!.cancel();
      _saveDraft();
    }
    _disposed = true;
    super.dispose();
  }
}
