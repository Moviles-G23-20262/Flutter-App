import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Unfinished forms, saved as one JSON value per key in shared_preferences. A draft is small and
/// always read whole, so a key-value store is enough. Drafts never contain passwords.
///
/// Losing a draft only means retyping it, so storage errors are swallowed.
class DraftStore {
  final Future<SharedPreferences> Function() _preferences;

  DraftStore([Future<SharedPreferences> Function()? preferences])
      : _preferences = preferences ?? SharedPreferences.getInstance;

  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final text = (await _preferences()).getString(key);
      if (text == null) return null;
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Exception {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> draft) async {
    try {
      await (await _preferences()).setString(key, jsonEncode(draft));
    } on Exception {
      // Not saved: the form still works, it just won't survive the app being closed.
    }
  }

  Future<void> remove(String key) async {
    try {
      await (await _preferences()).remove(key);
    } on Exception {
      // A stale draft is harmless; the next save replaces it.
    }
  }
}
