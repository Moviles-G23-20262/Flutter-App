import 'dart:async';

import 'package:flutter/foundation.dart';
import '../model/entities/exchange_entity.dart';
import '../model/entities/material_entity.dart';
import '../model/entities/notification_entity.dart';
import '../model/entities/pending_items.dart';
import '../model/exceptions/data_exceptions.dart';
import '../model/use_cases/marketplace_use_cases.dart';
import '../model/use_cases/pending_action_use_cases.dart';

/// The signed-in user's orders (purchases, sales) and notifications.
class AccountViewModel extends ChangeNotifier {
  final GetExchangesUseCase getExchanges;
  final GetNotificationsUseCase getNotifications;
  final MarkNotificationOpenedUseCase markNotificationOpened;
  final PlaceOrderUseCase placeOrder;
  final CompleteExchangeUseCase completeExchange;
  final CancelExchangeUseCase cancelExchange;
  final RateUserUseCase rateUser;

  /// Exchange steps saved offline (completion, rating, meeting proposal) and still unsent.
  final WatchPendingActionsUseCase? watchPendingActions;
  final DiscardPendingActionUseCase? discardPendingAction;

  AccountViewModel({
    //ViewModel
    required this.getExchanges,
    required this.getNotifications,
    required this.markNotificationOpened,
    required this.placeOrder,
    required this.completeExchange,
    required this.cancelExchange,
    required this.rateUser,
    this.watchPendingActions,
    this.discardPendingAction,
  });

  List<ExchangeEntity> _exchanges = const [];
  List<NotificationEntity> _notifications = const [];
  DateTime? _notificationsSavedAt;
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  int _generation = 0;
  List<PendingAction> _pendingActions = const [];
  StreamSubscription<List<PendingAction>>? _pendingSubscription;

  List<ExchangeEntity> get exchanges => _exchanges;
  List<NotificationEntity> get notifications => _notifications;

  /// Set while the notifications shown are the copy saved on the phone (offline): when it was saved.
  DateTime? get notificationsSavedAt => _notificationsSavedAt;
  bool get isLoading => _loading;
  bool get isFirstLoad => !_loadedOnce;
  String? get error => _error;
  int get unreadNotifications => _notifications.where((n) => n.isUnread).length;

  /// Steps saved on the phone and not confirmed by the server yet, oldest first.
  List<PendingAction> get pendingActions => _pendingActions;

  /// The buyer confirmed [exchangeId] offline; it shows as completed while it waits to be sent.
  bool isCompletionQueued(String exchangeId) => _queued(exchangeId, PendingActionKind.completeExchange);

  bool isRatingQueued(String exchangeId) => _queued(exchangeId, PendingActionKind.rate);

  /// A step of [exchangeId] the server refused, with its reason in [PendingAction.lastError].
  PendingAction? refusedStepFor(String exchangeId) => _pendingActions
      .where((a) => a.groupId == exchangeId && a.status == PendingStatus.refused)
      .firstOrNull;

  /// Only steps still waiting count: a refused one can be done again.
  bool _queued(String exchangeId, PendingActionKind kind) => _pendingActions
      .any((a) => a.groupId == exchangeId && a.kind == kind && a.status == PendingStatus.waiting);

  /// Follows [userId]'s queued steps. When one leaves the outbox (sent), the orders are read
  /// again, so the screens change from "saved" to "confirmed" by themselves.
  void watchPending(String userId) {
    final watch = watchPendingActions;
    if (watch == null) return;
    _pendingSubscription?.cancel();
    final generation = _generation;
    _pendingSubscription = watch.execute(userId).listen((actions) {
      if (generation != _generation) return;
      final stillThere = {for (final a in actions) a.id};
      final someLeft = _pendingActions.any((a) => !stillThere.contains(a.id));
      _pendingActions = actions;
      notifyListeners();
      if (someLeft) refreshExchanges();
    }, onError: (_) {});
  }

  /// The user gives up on a refused step.
  Future<void> discardPending(String actionId) async => discardPendingAction?.execute(actionId);

  Future<void> markAllNotificationsOpened() async {
  final unread = _notifications.where((n) => n.isUnread).toList();

  for (final notification in unread) {
    await openNotification(notification.id);
  }
}

  /// Orders [userId] placed, newest first (cancelled ones left out).
  List<ExchangeEntity> purchasesOf(String userId) => _sortedBy((e) => e.buyerId == userId);

  List<ExchangeEntity> salesOf(String userId) => _sortedBy((e) => e.sellerId == userId);

  /// Completed exchanges as buyer or seller.
  int swapCountOf(String userId) =>
      _exchanges.where((e) => e.isCompleted && (e.buyerId == userId || e.sellerId == userId)).length;

  /// What [userId] sold since the first day of the current month.
  double earnedThisMonth(String userId, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month);
    return salesOf(userId)
        .where((e) => e.isCompleted && !(e.completedAt ?? monthStart).isBefore(monthStart))
        .fold(0.0, (sum, e) => sum + e.price);
  }

  /// The open order between this buyer and seller for [materialId], if any.
  ExchangeEntity? pendingOrderFor(String materialId, String buyerId) => _exchanges
      .where((e) => e.isPending && e.materialId == materialId && e.buyerId == buyerId)
      .firstOrNull;

  /// The latest order (pending or completed) for [materialId] with [buyerId].
  ExchangeEntity? latestOrderFor(String materialId, String buyerId) => _sortedBy(
        (e) => e.materialId == materialId && e.buyerId == buyerId,
      ).firstOrNull;

  Future<void> load() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    // Both start at once; notifications load on their own, so their saved copy still shows offline.
    final notifications = _loadNotifications(generation);
    try {
      final exchanges = await getExchanges.execute();
      if (generation != _generation) return;
      _exchanges = exchanges;
    } on DataException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'Unexpected error. Please try again.';
    }
    await notifications;
    if (generation != _generation) return;
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
  }

  Future<void> _loadNotifications(int generation) async {
    try {
      final result = await getNotifications.execute();
      if (generation != _generation) return;
      _notifications = result.items;
      _notificationsSavedAt = result.savedAt;
    } on DataException catch (e) {
      if (generation == _generation) _error ??= e.message;
    } catch (_) {
      if (generation == _generation) _error ??= 'Unexpected error. Please try again.';
    }
  }

  /// Re-reads the orders only, e.g. after the other side may have changed one.
  Future<void> refreshExchanges() async {
    final generation = _generation;
    try {
      final exchanges = await getExchanges.execute();
      if (generation != _generation) return;
      _exchanges = exchanges;
      notifyListeners();
    } on DataException {
      // Keep what is on screen; the next full load shows the error.
    }
  }

  /// Orders [material]. Throws [DataException] with a message to show.
  Future<ExchangeEntity> order(MaterialEntity material, {required String buyerId}) async {
    final exchange = await placeOrder.execute(material, buyerId: buyerId);
    _upsert(exchange);
    return exchange;
  }

  /// Throws [DataException] with a message to show.
  Future<ExchangeEntity> complete(ExchangeEntity exchange, {MaterialConditionEnum? receivedCondition}) async {
    final updated = await completeExchange.execute(exchange, receivedCondition: receivedCondition);
    _upsert(updated);
    return updated;
  }

  /// Throws [DataException] with a message to show.
  Future<ExchangeEntity> cancel(ExchangeEntity exchange) async {
    final updated = await cancelExchange.execute(exchange);
    _upsert(updated);
    return updated;
  }

  /// Throws [DataException] with a message to show.
  Future<void> rate(NewRating rating) => rateUser.execute(rating);

  Future<void> openNotification(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || !_notifications[index].isUnread) return;
    final before = _notifications;
    _notifications = [
      for (final n in before)
        if (n.id == id) n.markOpened(DateTime.now()) else n,
    ];
    notifyListeners();
    try {
      await markNotificationOpened.execute(id);
    } on DataException {
      _notifications = before;
      notifyListeners();
    }
  }

  void clear() {
    _generation++;
    _pendingSubscription?.cancel();
    _pendingSubscription = null;
    _pendingActions = const [];
    _exchanges = const [];
    _notifications = const [];
    _notificationsSavedAt = null;
    _loading = false;
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    super.dispose();
  }

  /// The server returned a newer copy of [exchange] (e.g. right after completing it).
  void updateExchange(ExchangeEntity exchange) => _upsert(exchange);

  void _upsert(ExchangeEntity exchange) {
    final exists = _exchanges.any((e) => e.id == exchange.id);
    _exchanges = exists
        ? [for (final e in _exchanges) if (e.id == exchange.id) exchange else e]
        : [exchange, ..._exchanges];
    notifyListeners();
  }

  List<ExchangeEntity> _sortedBy(bool Function(ExchangeEntity) test) {
    final list = _exchanges.where((e) => e.status != ExchangeStatusEnum.CANCELLED && test(e)).toList();
    DateTime when(ExchangeEntity e) => e.completedAt ?? e.createdAt ?? DateTime(0);
    list.sort((a, b) => when(b).compareTo(when(a)));
    return list;
  }
}
