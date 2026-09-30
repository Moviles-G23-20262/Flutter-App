import 'package:flutter/material.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/user_entity.dart';

// ─── App Navigation State ─────────────────────────────────────────────────────

/// Identifies which main screen is active.
enum AppScreen {
  login,
  home,
  search,
  materialDetail,
  messages,
  profile,
  sellerHub,
  newListing,
  newListingSmart,
  confirmation,
}

// ─── App State ────────────────────────────────────────────────────────────────

/// Top-level state for the Campus Swap app.
/// Provides simple callback-based navigation used by all screens.
class AppState extends ChangeNotifier {
  AppScreen _currentScreen = AppScreen.login;
  MaterialEntity? _selectedMaterial;
  UserEntity? _currentUser;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isLoggedIn = false;

  // ── Getters ──────────────────────────────────────────────────────────────

  AppScreen get currentScreen  => _currentScreen;
  MaterialEntity? get selectedMaterial => _selectedMaterial;
  UserEntity? get currentUser  => _currentUser;
  ThemeMode get themeMode      => _themeMode;
  bool get isLoggedIn          => _isLoggedIn;

  Brightness get brightness =>
      _themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;

  // ── Navigation ────────────────────────────────────────────────────────────

  void navigateTo(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void openMaterialDetail(MaterialEntity material) {
    _selectedMaterial = material;
    _currentScreen = AppScreen.materialDetail;
    notifyListeners();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  void login(UserEntity user) {
    _currentUser = user;
    _isLoggedIn = true;
    _currentScreen = AppScreen.home;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _currentScreen = AppScreen.login;
    notifyListeners();
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

