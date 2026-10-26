import 'package:flutter/foundation.dart';

/// The phone's battery right now.
@immutable
class PowerStatus {
  /// 0–100.
  final int level;

  /// Plugged in (charging or already full).
  final bool charging;

  const PowerStatus({required this.level, required this.charging});

  @override
  bool operator ==(Object other) => other is PowerStatus && other.level == level && other.charging == charging;

  @override
  int get hashCode => Object.hash(level, charging);
}
