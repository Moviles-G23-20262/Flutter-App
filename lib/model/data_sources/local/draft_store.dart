import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Unfinished forms, saved as one JSON value per key in shared_preferences. A draft is small and
/// always read whole, so a key-value store is enough. Drafts never contain passwords.
///
/// Losing a draft only means retyping it, so storage errors are swallowed.
class DraftStore {
  static const String keyRegisterDraft = 'register_draft';
  static const String keySellDraft = 'sell_draft';
  static const Duration debounceDuration = Duration(milliseconds: 400);

  final Future<SharedPreferences> Function() _preferences;
  Timer? _debounceTimer;

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

  // ── Registration Draft (EC5) ────────────────────────────────────────────────

  void debouncedSaveRegisterDraft({
    required String fullName,
    required String major,
    required String email,
    String? faculty,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      saveRegisterDraft(
        fullName: fullName,
        major: major,
        email: email,
        faculty: faculty,
      );
    });
  }

  Future<void> saveRegisterDraft({
    required String fullName,
    required String major,
    required String email,
    String? faculty,
  }) async {
    await write(keyRegisterDraft, {
      'fullName': fullName,
      'major': major,
      'email': email,
      if (faculty != null) 'faculty': faculty,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getRegisterDraft() => read(keyRegisterDraft);

  Future<void> clearRegisterDraft() async {
    _debounceTimer?.cancel();
    await remove(keyRegisterDraft);
  }

  // ── Sell Draft (EC4) ───────────────────────────────────────────────────────

  void debouncedSaveSellDraft({
    required String userId,
    required Map<String, dynamic> draftData,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      saveSellDraft(userId: userId, draftData: draftData);
    });
  }

  Future<void> saveSellDraft({
    required String userId,
    required Map<String, dynamic> draftData,
  }) async {
    final copy = Map<String, dynamic>.from(draftData);
    copy['savedAt'] = DateTime.now().toIso8601String();
    await write('sell_draft:$userId', copy);
  }

  Future<Map<String, dynamic>?> getSellDraft({required String userId}) =>
      read('sell_draft:$userId');

  Future<void> clearSellDraft({required String userId}) async {
    _debounceTimer?.cancel();
    await remove('sell_draft:$userId');
  }
}
