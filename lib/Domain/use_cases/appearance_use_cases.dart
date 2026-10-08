import '../Entities/theme_preference.dart';
import '../repositories/appearance_repositories.dart';

class WatchAmbientLightUseCase {
  final AmbientLightRepository repository;
  WatchAmbientLightUseCase(this.repository);

  Stream<double> execute() => repository.luxReadings();
}

class LoadThemePreferenceUseCase {
  final ThemePreferenceRepository repository;
  LoadThemePreferenceUseCase(this.repository);

  /// Auto unless the user chose otherwise.
  Future<ThemePreference> execute() async => await repository.load() ?? ThemePreference.auto;
}

class SaveThemePreferenceUseCase {
  final ThemePreferenceRepository repository;
  SaveThemePreferenceUseCase(this.repository);

  Future<void> execute(ThemePreference preference) => repository.save(preference);
}

/// Decides dark or light from ambient light readings.
///
/// Two thresholds (hysteresis) and a hold time keep the theme steady: it turns dark only when it
/// has been darker than [darkBelowLux] for [hold], and light again only when it has been brighter
/// than [lightAboveLux] for [hold]. Readings in between keep the current theme, so a passing
/// shadow or a lamp switched on for a second does not make the screen flicker.
class AmbientThemePolicy {
  /// Below this the room is dim (a lecture hall with the projector on, a bus at night).
  static const double defaultDarkBelowLux = 50;

  /// Above this it is normally lit (offices and classrooms are around 300–500 lux).
  static const double defaultLightAboveLux = 200;

  final double darkBelowLux;
  final double lightAboveLux;
  final Duration hold;

  AmbientThemePolicy({
    this.darkBelowLux = defaultDarkBelowLux,
    this.lightAboveLux = defaultLightAboveLux,
    this.hold = const Duration(seconds: 3),
  }) : assert(darkBelowLux < lightAboveLux);

  bool? _dark;
  bool? _pending;
  DateTime? _pendingSince;

  /// The current decision; `null` until the first reading.
  bool? get isDark => _dark;

  /// Whether a switch is waiting for its hold time to pass.
  bool get hasPendingSwitch => _pending != null;

  /// How long until the pending switch can happen, or `null` if none is pending.
  Duration? timeUntilSwitch(DateTime now) {
    final since = _pendingSince;
    if (_pending == null || since == null) return null;
    final left = hold - now.difference(since);
    return left.isNegative ? Duration.zero : left;
  }

  /// Feeds one reading taken at [at]. Returns the new decision when it changes, otherwise `null`.
  bool? onReading(double lux, DateTime at) {
    final current = _dark;
    if (current == null) {
      // First reading: no flicker to protect against yet, so decide right away.
      _dark = lux < (darkBelowLux + lightAboveLux) / 2;
      return _dark;
    }

    final wantsDark = current ? lux <= lightAboveLux : lux < darkBelowLux;
    if (wantsDark == current) {
      _clearPending();
      return null;
    }
    if (_pending != wantsDark) {
      _pending = wantsDark;
      _pendingSince = at;
    }
    if (at.difference(_pendingSince!) >= hold) {
      _dark = wantsDark;
      _clearPending();
      return wantsDark;
    }
    return null;
  }

  void reset() {
    _dark = null;
    _clearPending();
  }

  void _clearPending() {
    _pending = null;
    _pendingSince = null;
  }
}
