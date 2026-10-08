import '../Entities/power_status.dart';

abstract class BatteryRepository {
  /// The battery level and charging state, each time either changes (and periodically).
  /// Emits nothing where the battery cannot be read.
  Stream<PowerStatus> watch();
}
