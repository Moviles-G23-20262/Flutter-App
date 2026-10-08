import 'package:shared_preferences/shared_preferences.dart';

import '../../Domain/Entities/theme_preference.dart';
import '../../Domain/repositories/appearance_repositories.dart';
import '../data_sources/ambient_light_data_source.dart';

class AmbientLightRepositoryImpl implements AmbientLightRepository {
  final AmbientLightDataSource sensor;

  AmbientLightRepositoryImpl(this.sensor);

  @override
  Stream<double> luxReadings() => sensor.luxReadings();
}

/// Keeps the choice on the device; it is a display setting, not account data.
class ThemePreferenceRepositoryImpl implements ThemePreferenceRepository {
  static const _key = 'theme_preference';

  @override
  Future<ThemePreference?> load() async {
    try {
      final stored = (await SharedPreferences.getInstance()).getString(_key);
      return ThemePreference.values.where((p) => p.name == stored).firstOrNull;
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> save(ThemePreference preference) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, preference.name);
    } on Exception {
      // Not saving only means the choice resets next launch.
    }
  }
}
