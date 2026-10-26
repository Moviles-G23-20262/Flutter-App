import 'dart:async';

import 'package:flutter/foundation.dart';
import '../model/entities/power_status.dart';
import '../model/use_cases/power_use_cases.dart';

/// Battery saver: on a low battery that is not charging, the app polls the server less often.
/// It switches on and off by itself as the battery changes; the user does nothing.
class PowerViewModel extends ChangeNotifier {
  final WatchBatteryUseCase watchBattery;
  final PowerSavingPolicy policy;

  PowerViewModel({required this.watchBattery, this.policy = const PowerSavingPolicy()});

  StreamSubscription<PowerStatus>? _subscription;
  PowerStatus? _status;
  bool _saving = false;

  bool get isSaving => _saving;
  PowerStatus? get status => _status;

  void start() {
    _subscription ??= watchBattery.execute().listen(_onStatus, onError: (_) {});
  }

  void _onStatus(PowerStatus status) {
    _status = status;
    final saving = policy.decide(status, savingNow: _saving);
    if (saving == _saving) return;
    _saving = saving;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
