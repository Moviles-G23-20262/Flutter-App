import '../Entities/power_status.dart';
import '../repositories/power_repositories.dart';

class WatchBatteryUseCase {
  final BatteryRepository repository;
  WatchBatteryUseCase(this.repository);

  Stream<PowerStatus> execute() => repository.watch();
}

/// Decides when the app should save battery: on a low battery that is not charging.
///
/// It turns on at [onAtOrBelow] percent and only turns off again at [offAtOrAbove] percent
/// (or when the phone is plugged in), so a battery hovering around 20 % does not make the
/// app switch back and forth.
class PowerSavingPolicy {
  static const int defaultOnAtOrBelow = 20;
  static const int defaultOffAtOrAbove = 25;

  final int onAtOrBelow;
  final int offAtOrAbove;

  const PowerSavingPolicy({
    this.onAtOrBelow = defaultOnAtOrBelow,
    this.offAtOrAbove = defaultOffAtOrAbove,
  }) : assert(onAtOrBelow < offAtOrAbove);

  /// Whether to save battery given the new [status] and whether it was saving already.
  bool decide(PowerStatus status, {required bool savingNow}) {
    if (status.charging) return false;
    if (savingNow) return status.level < offAtOrAbove;
    return status.level <= onAtOrBelow;
  }
}
