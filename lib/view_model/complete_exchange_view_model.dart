import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/entities/exchange_entity.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/rating_draft.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/pending_action_use_cases.dart';
import '../model/use_cases/rating_draft_use_cases.dart';

/// How a submit ended.
enum ExchangeSubmitOutcome {
  /// The server has it: the exchange was confirmed/completed and/or the rating is in.
  sent,

  /// No connection: saved on the phone, and sent by the outbox when the connection is back.
  savedOffline,

  /// Refused or invalid; [CompleteExchangeViewModel.errorMessage] says why. The form is kept.
  failed,
}

/// The complete-exchange screen: two-sided handoff confirmation (buyer item check, seller handoff
/// confirmation) and peer rating once the exchange is completed.
///
/// What is entered is saved as a draft 0.4 s after the last change and restored when the screen
/// opens again. Without a connection, the completion and the rating are queued in the outbox.
class CompleteExchangeViewModel extends ChangeNotifier {
  static const Duration draftDelay = Duration(milliseconds: 400);
  static const List<String> checklist = [
    'Matches the photos',
    'Condition is as listed',
    'Everything included',
    'Works as expected',
  ];
  static const List<String> ratingTags = [
    'Punctual',
    'Item as described',
    'Friendly',
    'Good communication',
    'Fair price',
  ];

  final String userId;
  final CompleteExchangeUseCase completeExchange;
  final RateUserUseCase rateUser;
  final QueueExchangeCompletionUseCase queueCompletion;
  final QueueRatingUseCase queueRating;
  final LoadRatingDraftUseCase loadDraft;
  final SaveRatingDraftUseCase saveDraft;
  final ClearRatingDraftUseCase clearDraft;

  /// The server returned the updated/completed exchange; the app updates its lists with it.
  final void Function(ExchangeEntity exchange) onExchangeUpdated;

  CompleteExchangeViewModel({
    required ExchangeEntity exchange,
    required this.userId,
    required this.completeExchange,
    required this.rateUser,
    required this.queueCompletion,
    required this.queueRating,
    required this.loadDraft,
    required this.saveDraft,
    required this.clearDraft,
    required this.onExchangeUpdated,
    this._completionQueued = false,
    this._ratingQueued = false,
  })  : _exchange = exchange,
        _received = exchange.material?.condition;

  ExchangeEntity _exchange;
  final Set<int> _checked = {};
  MaterialConditionEnum? _received;
  int _stars = 0;
  final Set<String> _tags = {};
  String _review = '';
  bool _completionQueued;
  bool _ratingQueued;
  bool _submitting = false;
  bool _restoredDraft = false;
  String _errorMessage = '';
  Timer? _draftTimer;
  bool _disposed = false;

  ExchangeEntity get exchange => _exchange;
  Set<int> get checkedItems => _checked;
  MaterialConditionEnum? get receivedCondition => _received;
  int get stars => _stars;
  Set<String> get selectedTags => _tags;
  String get review => _review;
  bool get isSubmitting => _submitting;
  String get errorMessage => _errorMessage;

  /// A saved draft was put back into the form.
  bool get restoredDraft => _restoredDraft;

  bool get isBuyer => _exchange.buyerId == userId;
  bool get isCancelled => _exchange.status == ExchangeStatusEnum.CANCELLED;

  /// Confirmed offline; it counts as done here while it waits to be sent.
  bool get completionQueued => _completionQueued;

  /// Everything is saved and waiting for the connection: nothing left to fill in.
  bool get ratingQueued => _ratingQueued;

  /// The buyer still has to check the item and confirm their side of the exchange.
  bool get needsCheck => isBuyer && _exchange.isPending && !_exchange.hasConfirmed(userId) && !_completionQueued;

  /// The seller still has to confirm handing over the item so the sale can close.
  bool get needsSellerConfirmation =>
      !isBuyer && _exchange.isPending && !_exchange.hasConfirmed(userId) && !_completionQueued;

  /// True when this user already confirmed their side and is waiting for the other party.
  bool get waitingForOther => _exchange.isPending && _exchange.hasConfirmed(userId) && !_completionQueued;

  /// Backwards-compatible alias: true only when the user has nothing left to confirm while pending.
  bool get waitingForBuyer => waitingForOther;

  /// Whether the user should fill in a peer rating on this submission (either the exchange is
  /// already completed, or the buyer is submitting the checklist/rating flow, or the seller is
  /// closing an exchange the buyer already confirmed).
  bool get showsRatingSection =>
      !isCancelled && !waitingForOther && (!needsSellerConfirmation || _exchange.otherHasConfirmed(userId));

  bool get allChecked => _checked.length == checklist.length;

  bool get canSubmit {
    if (_submitting || _ratingQueued || waitingForOther || isCancelled) return false;
    if (needsSellerConfirmation && !_exchange.otherHasConfirmed(userId)) {
      return true;
    }
    return _stars > 0 && (!needsCheck || allChecked);
  }

  String get otherFirstName => _exchange.otherParty(userId)?.fullName.split(' ').first ?? 'them';

  /// Restores the draft, if there is one. Call once when the screen opens.
  Future<void> init() async {
    final draft = await loadDraft.execute(userId: userId, exchangeId: _exchange.id);
    if (draft == null || _disposed) return;
    _checked
      ..clear()
      ..addAll(draft.checkedItems.where((i) => i >= 0 && i < checklist.length));
    _received = draft.receivedCondition ?? _received;
    _stars = draft.stars;
    _tags
      ..clear()
      ..addAll(draft.tags.where(ratingTags.contains));
    _review = draft.review;
    _restoredDraft = !draft.isEmpty;
    _notify();
  }

  void toggleCheck(int index) {
    _checked.contains(index) ? _checked.remove(index) : _checked.add(index);
    _changed();
  }

  void setReceivedCondition(MaterialConditionEnum condition) {
    _received = condition;
    _changed();
  }

  void setStars(int stars) {
    _stars = stars.clamp(1, 5);
    _changed();
  }

  void toggleTag(String tag) {
    _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag);
    _changed();
  }

  /// The review is typed in a text field, which draws itself: only the draft is updated.
  void setReview(String review) {
    _review = review;
    _errorMessage = '';
    _scheduleDraftSave();
  }

  Future<ExchangeSubmitOutcome> submit() async {
    if (!canSubmit) return ExchangeSubmitOutcome.failed;
    _submitting = true;
    _errorMessage = '';
    _notify();

    final needsConfirm = needsCheck || needsSellerConfirmation;
    final hasRating = _stars > 0;
    final rating = hasRating
        ? NewRating(
            exchangeId: _exchange.id,
            ratedId: isBuyer ? _exchange.sellerId : _exchange.buyerId,
            stars: _stars,
            tags: _tags.toList(),
            review: _review,
          )
        : null;
    var offline = false;
    try {
      if (needsConfirm) {
        try {
          _exchange = await completeExchange.execute(
            _exchange,
            receivedCondition: isBuyer ? _received : null,
          );
          onExchangeUpdated(_exchange);
        } on NoConnectionException {
          offline = true;
          await queueCompletion.execute(
            ownerId: userId,
            exchange: _exchange,
            receivedCondition: isBuyer ? _received : null,
          );
          _completionQueued = true;
        }
      }
      if (offline) {
        // The rating must follow the completion, so it waits in the outbox behind it.
        if (rating != null) {
          await queueRating.execute(ownerId: userId, rating: rating);
          _ratingQueued = true;
        }
      } else if ((_exchange.isCompleted || _completionQueued) && rating != null) {
        // Only post the rating once the server confirms both sides completed the exchange;
        // otherwise keep the rating draft so the user can rate once the other side confirms.
        try {
          await rateUser.execute(rating);
        } on NoConnectionException {
          offline = true;
          await queueRating.execute(ownerId: userId, rating: rating);
          _ratingQueued = true;
        }
      }
      if (_exchange.isCompleted || offline) {
        _draftTimer?.cancel();
        await clearDraft.execute(userId: userId, exchangeId: _exchange.id);
      }
      return offline ? ExchangeSubmitOutcome.savedOffline : ExchangeSubmitOutcome.sent;
    } on DataException catch (e) {
      // The exchange may have been completed even if the rating failed; the form follows suit.
      _errorMessage = e.message;
      return ExchangeSubmitOutcome.failed;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void _changed() {
    _errorMessage = '';
    _notify();
    _scheduleDraftSave();
  }

  /// Debounce: every change restarts the timer, so only the last state is written.
  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDelay, _saveDraft);
  }

  Future<void> _saveDraft() => saveDraft.execute(
        userId: userId,
        exchangeId: _exchange.id,
        draft: RatingDraft(
          checkedItems: Set.of(_checked),
          receivedCondition: _received,
          stars: _stars,
          tags: Set.of(_tags),
          review: _review,
        ),
      );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A change still waiting for its timer is written now, so leaving the screen loses nothing.
  @override
  void dispose() {
    _disposed = true;
    if (_draftTimer?.isActive ?? false) {
      _draftTimer!.cancel();
      if (!_ratingQueued) _saveDraft();
    }
    super.dispose();
  }
}
