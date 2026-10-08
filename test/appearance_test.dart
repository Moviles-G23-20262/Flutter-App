import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/Domain/Entities/theme_preference.dart';
import 'package:flutter_front_end/Domain/repositories/appearance_repositories.dart';
import 'package:flutter_front_end/Domain/use_cases/appearance_use_cases.dart';
import 'package:flutter_front_end/Presentation/State%20Management/theme_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSensor implements AmbientLightRepository {
  final controller = StreamController<double>.broadcast();
  int listeners = 0;

  @override
  Stream<double> luxReadings() {
    listeners++;
    return controller.stream;
  }
}

class _FakePrefs implements ThemePreferenceRepository {
  ThemePreference? stored;

  @override
  Future<ThemePreference?> load() async => stored;

  @override
  Future<void> save(ThemePreference preference) async => stored = preference;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AmbientThemePolicy', () {
    final t0 = DateTime(2026, 10, 7, 12);
    DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

    test('the first reading decides right away', () {
      expect(AmbientThemePolicy().onReading(20, t0), isTrue);
      expect(AmbientThemePolicy().onReading(400, t0), isFalse);
    });

    test('turns dark only after it stays dim for the hold time', () {
      final policy = AmbientThemePolicy();
      policy.onReading(400, at(0));

      expect(policy.onReading(10, at(1)), isNull);
      expect(policy.isDark, isFalse);
      expect(policy.onReading(12, at(3)), isNull);
      expect(policy.onReading(11, at(4)), isTrue);
      expect(policy.isDark, isTrue);
    });

    test('a brief shadow does not switch the theme', () {
      final policy = AmbientThemePolicy();
      policy.onReading(400, at(0));

      policy.onReading(10, at(1)); // shadow
      policy.onReading(350, at(2)); // gone again
      expect(policy.onReading(10, at(5)), isNull, reason: 'the hold restarts after the light came back');
      expect(policy.isDark, isFalse);
    });

    test('readings between the thresholds keep the current theme', () {
      final policy = AmbientThemePolicy();
      policy.onReading(10, at(0)); // dark
      expect(policy.onReading(150, at(10)), isNull);
      expect(policy.isDark, isTrue);

      final light = AmbientThemePolicy()..onReading(400, at(0));
      expect(light.onReading(80, at(10)), isNull);
      expect(light.isDark, isFalse);
    });

    test('reports how long a pending switch still has to wait', () {
      final policy = AmbientThemePolicy()..onReading(400, at(0));
      policy.onReading(10, at(1));
      expect(policy.timeUntilSwitch(at(2)), const Duration(seconds: 2));
      expect(AmbientThemePolicy().timeUntilSwitch(at(0)), isNull);
    });
  });

  group('ThemeState', () {
    late _FakeSensor sensor;
    late _FakePrefs prefs;

    ThemeState build({Duration timeout = const Duration(milliseconds: 50)}) => ThemeState(
          watchAmbientLight: WatchAmbientLightUseCase(sensor),
          loadPreference: LoadThemePreferenceUseCase(prefs),
          savePreference: SaveThemePreferenceUseCase(prefs),
          policy: AmbientThemePolicy(hold: const Duration(milliseconds: 30)),
          sensorTimeout: timeout,
        );

    setUp(() {
      sensor = _FakeSensor();
      prefs = _FakePrefs();
    });

    test('Auto by default: follows the sensor', () async {
      final theme = build();
      await theme.start();
      expect(theme.preference, ThemePreference.auto);

      sensor.controller.add(5);
      await Future<void>.delayed(Duration.zero);
      expect(theme.themeMode, ThemeMode.dark);
      expect(theme.lux.value, 5);

      sensor.controller.add(800);
      await Future<void>.delayed(const Duration(milliseconds: 60)); // hold time, with no new reading
      expect(theme.themeMode, ThemeMode.light);
      theme.dispose();
    });

    test('without readings it falls back to the system theme', () async {
      final theme = build();
      await theme.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(theme.sensorStatus, LightSensorStatus.unavailable);
      expect(theme.themeMode, ThemeMode.system);
      theme.dispose();
    });

    test('a fixed choice stops the sensor, is saved, and ignores readings', () async {
      final theme = build();
      await theme.start();
      await theme.setPreference(ThemePreference.light);

      expect(prefs.stored, ThemePreference.light);
      expect(theme.sensorStatus, LightSensorStatus.off);
      expect(sensor.controller.hasListener, isFalse);
      sensor.controller.add(1);
      expect(theme.themeMode, ThemeMode.light);
      theme.dispose();
    });

    test('the quick toggle pins the opposite of what is showing', () async {
      final theme = build();
      await theme.start();
      sensor.controller.add(5);
      await Future<void>.delayed(Duration.zero);

      await theme.toggle();
      expect(theme.preference, ThemePreference.light);
      await theme.toggle();
      expect(theme.preference, ThemePreference.dark);
      theme.dispose();
    });

    test('stops reading the sensor in the background and resumes on return', () async {
      final theme = build();
      await theme.start();
      expect(sensor.controller.hasListener, isTrue);

      theme.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(sensor.controller.hasListener, isFalse);
      theme.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(sensor.controller.hasListener, isTrue);
      theme.dispose();
    });

    test('remembers the saved choice', () async {
      prefs.stored = ThemePreference.dark;
      final theme = build();
      await theme.start();
      expect(theme.themeMode, ThemeMode.dark);
      expect(sensor.listeners, 0);
      theme.dispose();
    });
  });
}
