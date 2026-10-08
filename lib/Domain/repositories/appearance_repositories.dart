import '../Entities/theme_preference.dart';

abstract class AmbientLightRepository {
  /// Illuminance around the phone, in lux, each time it changes.
  /// Emits nothing on a phone without a light sensor.
  Stream<double> luxReadings();
}

abstract class ThemePreferenceRepository {
  /// The saved choice, or `null` if the user never picked one.
  Future<ThemePreference?> load();

  Future<void> save(ThemePreference preference);
}
