import 'package:shared_preferences/shared_preferences.dart';

import '../mobile_data_preference_repository.dart';

/// Stores the `allow_mobile_data` preference locally (defaults to `false` to protect data plans).
class MobileDataPreferenceRepositoryImpl implements MobileDataPreferenceRepository {
  static const prefKey = 'allow_mobile_data';

  final Future<SharedPreferences> Function() _prefs;

  MobileDataPreferenceRepositoryImpl({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  @override
  Future<bool> isAllowed() async {
    final p = await _prefs();
    return p.getBool(prefKey) ?? false;
  }

  @override
  Future<void> setAllowed(bool allowed) async {
    final p = await _prefs();
    await p.setBool(prefKey, allowed);
  }
}
