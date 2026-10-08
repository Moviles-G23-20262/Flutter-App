import 'dart:async';

import 'package:battery_plus/battery_plus.dart';

import '../../Domain/Entities/power_status.dart';
import '../../Domain/repositories/power_repositories.dart';

/// The phone's battery through battery_plus. Android reports charging changes as events,
/// but not the level, so the level is also re-read every minute.
class BatteryDataSource implements BatteryRepository {
  static const _levelRefresh = Duration(minutes: 1);

  final Battery _battery;

  BatteryDataSource([Battery? battery]) : _battery = battery ?? Battery();

  @override
  Stream<PowerStatus> watch() {
    late final StreamController<PowerStatus> controller;
    StreamSubscription<BatteryState>? stateChanges;
    Timer? refresh;
    var state = BatteryState.unknown;

    Future<void> emit() async {
      try {
        final level = await _battery.batteryLevel;
        if (controller.isClosed) return;
        controller.add(PowerStatus(
          level: level,
          charging: state == BatteryState.charging || state == BatteryState.full,
        ));
      } on Exception {
        // No battery information on this device: emit nothing, so nothing changes.
      }
    }

    controller = StreamController<PowerStatus>(
      onListen: () {
        stateChanges = _battery.onBatteryStateChanged.listen((s) {
          state = s;
          emit();
        }, onError: (_) {});
        emit();
        refresh = Timer.periodic(_levelRefresh, (_) => emit());
      },
      onCancel: () {
        stateChanges?.cancel();
        refresh?.cancel();
      },
    );
    return controller.stream;
  }
}
