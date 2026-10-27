import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages draft auto-saving with debouncing to local `shared_preferences`.
///
/// Ensures student progress in registration or creating a listing is never lost
/// if the app is closed, killed by the OS, or the network connection drops.
class DraftStore {
  static const String keyRegisterDraft = 'register_draft';
  static const String keySellDraft = 'sell_draft';
  static const Duration debounceDuration = Duration(milliseconds: 400);

  Timer? _debounceTimer;

  /// Saves registration draft (excluding sensitive credentials like password) after 400ms debounce.
  void debouncedSaveRegisterDraft({
    required String fullName,
    required String major,
    required String email,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      saveRegisterDraft(fullName: fullName, major: major, email: email);
    });
  }

  Future<void> saveRegisterDraft({
    required String fullName,
    required String major,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'fullName': fullName,
      'major': major,
      'email': email,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(keyRegisterDraft, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getRegisterDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyRegisterDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRegisterDraft() async {
    _debounceTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyRegisterDraft);
  }

  /// Saves sell form draft after 400ms debounce.
  void debouncedSaveSellDraft(Map<String, dynamic> draftData) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      saveSellDraft(draftData);
    });
  }

  Future<void> saveSellDraft(Map<String, dynamic> draftData) async {
    final prefs = await SharedPreferences.getInstance();
    final copy = Map<String, dynamic>.from(draftData);
    copy['savedAt'] = DateTime.now().toIso8601String();
    await prefs.setString(keySellDraft, jsonEncode(copy));
  }

  Future<Map<String, dynamic>?> getSellDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keySellDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSellDraft() async {
    _debounceTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keySellDraft);
  }
}
