import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import '../../Domain/Entities/theme_preference.dart';
import '../../Domain/use_cases/appearance_use_cases.dart';

enum LightSensorStatus {
  /// Listening, no reading yet.
  waiting,

  /// Readings are arriving; the theme follows them.
  reading,

  /// No reading arrived in time (no sensor on this phone): the system theme is used instead.
  unavailable,

  /// Not listening: a fixed theme was chosen or the app is in the background.
  off,
}

/// Light or dark for the whole app. In [ThemePreference.auto] the theme adapts to the light
/// around the phone, read from its ambient light sensor, with no action from the user.
class ThemeState extends ChangeNotifier with WidgetsBindingObserver {
  final WatchAmbientLightUseCase watchAmbientLight;
  final LoadThemePreferenceUseCase loadPreference;
  final SaveThemePreferenceUseCase savePreference;
  final AmbientThemePolicy policy;

  /// How long to wait for a first reading before deciding the phone has no light sensor.
  final Duration sensorTimeout;

  ThemeState({
    required this.watchAmbientLight,
    required this.loadPreference,
    required this.savePreference,
    AmbientThemePolicy? policy,
    this.sensorTimeout = const Duration(seconds: 4),
  }) : policy = policy ?? AmbientThemePolicy();

  ThemePreference _preference = ThemePreference.auto;
  LightSensorStatus _status = LightSensorStatus.off;
  StreamSubscription<double>? _subscription;
  Timer? _timeout;
  Timer? _holdTimer;
  double? _lastLux;
  bool _started = false;
  bool _foreground = true;

  /// The latest reading, for showing in settings. Separate from [ThemeState] so a stream of
  /// readings does not rebuild the whole app; only a change of theme does.
  final ValueNotifier<double?> lux = ValueNotifier(null);

  ThemePreference get preference => _preference;
  LightSensorStatus get sensorStatus => _status;

  ThemeMode get themeMode {
    switch (_preference) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.auto:
        final dark = policy.isDark;
        if (_status == LightSensorStatus.unavailable || dark == null) return ThemeMode.system;
        return dark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  /// What is on screen right now, resolving "system" with the phone's own setting.
  bool get isDark {
    switch (themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }

  /// Loads the saved choice and starts the sensor if it is Auto. Call once at startup.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _preference = await loadPreference.execute();
    _apply();
  }

  Future<void> setPreference(ThemePreference preference) async {
    if (preference == _preference) return;
    _preference = preference;
    _apply();
    await savePreference.execute(preference);
  }

  /// The quick sun/moon button: pins the opposite of what is showing now.
  Future<void> toggle() => setPreference(isDark ? ThemePreference.light : ThemePreference.dark);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The sensor costs battery; only read it while the app is on screen.
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _apply();
  }

  @override
  void didChangePlatformBrightness() {
    // Matters when following the system theme (no sensor).
    if (themeMode == ThemeMode.system) notifyListeners();
  }

  void _apply() {
    if (_preference == ThemePreference.auto && _foreground) {
      _listen();
    } else {
      _stopListening();
      _status = LightSensorStatus.off;
    }
    notifyListeners();
  }

  void _listen() {
    if (_subscription != null) return;
    if (_status != LightSensorStatus.unavailable) _status = LightSensorStatus.waiting;
    _subscription = watchAmbientLight.execute().listen(_onLux, onError: (_) => _markUnavailable());
    _timeout = Timer(sensorTimeout, () {
      if (_status == LightSensorStatus.waiting) _markUnavailable();
    });
  }

  void _onLux(double value) {
    _lastLux = value;
    lux.value = value;
    final firstReading = _status != LightSensorStatus.reading;
    _status = LightSensorStatus.reading;
    _timeout?.cancel();
    // Back from the background the phone may be somewhere else entirely: take the first reading
    // at face value instead of waiting out the hold time. Until it arrives the old theme stays.
    if (firstReading) policy.reset();
    _decide(value, notifyAnyway: firstReading);
  }

  void _decide(double value, {bool notifyAnyway = false}) {
    final changed = policy.onReading(value, DateTime.now());
    // The sensor only reports changes, so a switch waiting for its hold time needs a nudge.
    _holdTimer?.cancel();
    final wait = policy.timeUntilSwitch(DateTime.now());
    if (wait != null) {
      _holdTimer = Timer(wait, () {
        final last = _lastLux;
        if (last != null) _decide(last);
      });
    }
    if (changed != null || notifyAnyway) notifyListeners();
  }

  void _markUnavailable() {
    _status = LightSensorStatus.unavailable;
    notifyListeners();
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _timeout?.cancel();
    _holdTimer?.cancel();
  }

  @override
  void dispose() {
    _stopListening();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    lux.dispose();
    super.dispose();
  }
}
