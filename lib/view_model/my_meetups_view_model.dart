import 'package:flutter/foundation.dart';

import '../model/entities/exchange_entity.dart';
import '../model/rules/my_meetups.dart';

/// "My meetups": the signed-in user's open orders grouped into upcoming meetings, meetings to
/// confirm and orders still without a place and time.
///
/// It needs no request of its own: it reads the orders the app already holds (and keeps offline)
/// through [exchanges], follows their changes through [changes], and [refresh] asks for them
/// again. The grouping is computed once per version of the orders list, not on every rebuild.
class MyMeetupsViewModel extends ChangeNotifier {
  final String userId;
  final List<ExchangeEntity> Function() exchanges;
  final Listenable changes;
  final Future<void> Function() refresh;
  final bool Function() isLoading;
  final DateTime Function() _now;

  MyMeetupsViewModel({
    required this.userId,
    required this.exchanges,
    required this.changes,
    required this.refresh,
    required this.isLoading,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    changes.addListener(_onChanged);
  }

  List<ExchangeEntity>? _groupedFrom;
  DateTime? _groupedAt;
  MyMeetups _meetups = MyMeetups.empty;
  bool _disposed = false;

  /// Grouped again when the orders change, or after a minute (a meeting may have ended).
  MyMeetups get meetups {
    final source = exchanges();
    final now = _now();
    final groupedAt = _groupedAt;
    if (!identical(source, _groupedFrom) || groupedAt == null || now.difference(groupedAt).inMinutes >= 1) {
      _meetups = MyMeetups.from(source, userId: userId, now: now);
      _groupedFrom = source;
      _groupedAt = now;
    }
    return _meetups;
  }

  bool get loading => isLoading();
  DateTime get now => _now();

  void _onChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    changes.removeListener(_onChanged);
    super.dispose();
  }
}
