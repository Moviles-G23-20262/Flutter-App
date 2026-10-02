import 'package:flutter/foundation.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import '../../Domain/use_cases/marketplace_use_cases.dart';

/// The signed-in user's history: completed exchanges (purchases, sales) and notifications.
class AccountState extends ChangeNotifier {
  final GetExchangesUseCase getExchanges;
  final GetNotificationsUseCase getNotifications;
  final MarkNotificationOpenedUseCase markNotificationOpened;

  AccountState({
    required this.getExchanges,
    required this.getNotifications,
    required this.markNotificationOpened,
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

  /// Newest first.
  List<ExchangeEntity> purchasesOf(String userId) => _sortedBy((e) => e.buyerId == userId);

  List<ExchangeEntity> salesOf(String userId) => _sortedBy((e) => e.sellerId == userId);

  /// Completed exchanges as buyer or seller.
  int swapCountOf(String userId) =>
      _exchanges.where((e) => e.buyerId == userId || e.sellerId == userId).length;

  /// What [userId] sold since the first day of the current month.
  double earnedThisMonth(String userId, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month);
    return salesOf(userId)
        .where((e) => !(e.completedAt ?? monthStart).isBefore(monthStart))
        .fold(0.0, (sum, e) => sum + e.price);
  }

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

  List<ExchangeEntity> _sortedBy(bool Function(ExchangeEntity) test) {
    final list = _exchanges.where(test).toList();
    list.sort((a, b) => (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    return list;
  }
}
