import 'package:flutter/material.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/user_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import 'account_state.dart';
import 'chat_state.dart';
import 'marketplace_state.dart';

// ─── App Navigation State ─────────────────────────────────────────────────────

/// Identifies which main screen is active.
enum AppScreen {
  login,
  register,
  home,
  search,
  materialDetail,
  messages,
  profile,
  favorites,
  notifications,
  sellerHub,
  newListing,
  newListingSmart,
  confirmation,
}

// ─── App State ────────────────────────────────────────────────────────────────

/// Top-level state for the Campus Swap app.
/// Provides simple callback-based navigation used by all screens.
class AppState extends ChangeNotifier {
  /// Called after the user logs out, to clear the stored session.
  final Future<void> Function()? onLogout;

  /// Server-backed data; loaded on login and emptied on logout.
  final MarketplaceState marketplace;
  final ChatState chats;
  final AccountState account;

  AppState({
    this.onLogout,
    required this.marketplace,
    required this.chats,
    required this.account,
  });

  AppScreen _currentScreen = AppScreen.login;
  MaterialEntity? _selectedMaterial;
  UserEntity? _currentUser;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isLoggedIn = false;
  bool _restoringSession = true;

  // ── Getters ──────────────────────────────────────────────────────────────

  AppScreen get currentScreen  => _currentScreen;
  MaterialEntity? get selectedMaterial => _selectedMaterial;
  UserEntity? get currentUser  => _currentUser;
  ThemeMode get themeMode      => _themeMode;
  bool get isLoggedIn          => _isLoggedIn;

  /// True until the startup attempt to restore a stored session has finished.
  bool get restoringSession    => _restoringSession;

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
    _restoringSession = false;
    _currentUser = user;
    _isLoggedIn = true;
    _currentScreen = AppScreen.home;
    notifyListeners();
    marketplace.load();
    chats.start(user.id);
    account.load();
  }

  /// "Message seller": opens (creating it if needed) the conversation about [material].
  /// Returns an error message to show the user, or `null` when the chat opened.
  Future<String?> messageSeller(MaterialEntity material) async {
    if (material.sellerId == _currentUser?.id) return 'This is your own listing.';
    try {
      final room = await chats.openRoomFor(material.id);
      openChat(room.id);
      return null;
    } on DataException catch (e) {
      return e.message;
    }
  }

  /// Opens the conversation [roomId] in the Messages tab.
  void openChat(String roomId) {
    chats.openRoom(roomId);
    navigateTo(AppScreen.messages);
  }

  /// No stored session (or it is no longer valid): show the login screen.
  void sessionRestoreFinished() {
    _restoringSession = false;
    notifyListeners();
  }

  void logout() {
    marketplace.clear();
    chats.clear();
    account.clear();
    _currentUser = null;
    _isLoggedIn = false;
    _currentScreen = AppScreen.login;
    notifyListeners();
    onLogout?.call();
  }

  @override
  void dispose() {
    marketplace.dispose();
    chats.dispose();
    account.dispose();
    super.dispose();
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

