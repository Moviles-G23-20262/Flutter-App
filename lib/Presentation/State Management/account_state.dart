import 'package:flutter/foundation.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/use_cases/marketplace_use_cases.dart';

/// The signed-in user's orders (purchases, sales) and notifications.
class AccountState extends ChangeNotifier {
  final GetExchangesUseCase getExchanges;
  final GetNotificationsUseCase getNotifications;
  final MarkNotificationOpenedUseCase markNotificationOpened;
  final PlaceOrderUseCase placeOrder;
  final CompleteExchangeUseCase completeExchange;
  final CancelExchangeUseCase cancelExchange;
  final RateUserUseCase rateUser;

  AccountState({
    required this.getExchanges,
    required this.getNotifications,
    required this.markNotificationOpened,
    required this.placeOrder,
    required this.completeExchange,
    required this.cancelExchange,
    required this.rateUser,
  });

  List<ExchangeEntity> _exchanges = const [];
  List<NotificationEntity> _notifications = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  int _generation = 0;

  List<ExchangeEntity> get exchanges => _exchanges;
  List<NotificationEntity> get notifications => _notifications;
  bool get isLoading => _loading;
  bool get isFirstLoad => !_loadedOnce;
  String? get error => _error;
  int get unreadNotifications => _notifications.where((n) => n.isUnread).length;

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
    try {
      final results = await Future.wait([getExchanges.execute(), getNotifications.execute()]);
      if (generation != _generation) return;
      _exchanges = results[0] as List<ExchangeEntity>;
      _notifications = results[1] as List<NotificationEntity>;
    } on DataException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'Unexpected error. Please try again.';
    }
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
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
    _exchanges = const [];
    _notifications = const [];
    _loading = false;
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }

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
