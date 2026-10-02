import 'package:flutter/material.dart';
import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/use_cases/meetup_use_cases.dart';
import '../../Domain/Entities/user_entity.dart';
import '../../Domain/exceptions/data_exceptions.dart';
import 'account_state.dart';
import 'chat_state.dart';
import 'marketplace_state.dart';
import 'meeting_planner_state.dart';
import 'schedule_state.dart';

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

  /// "Order Placed", right after buying.
  confirmation,

  /// Pick a safe zone and a shared free hour for the open chat.
  meetingPlanner,

  /// Check the item and rate the other person.
  completeExchange,

  /// The user's weekly classes.
  schedule,
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
  final ScheduleState schedule;
  final MeetupUseCases meetups;

  AppState({
    this.onLogout,
    required this.marketplace,
    required this.chats,
    required this.account,
    required this.schedule,
    required this.meetups,
  });

  AppScreen _currentScreen = AppScreen.login;
  MaterialEntity? _selectedMaterial;
  ExchangeEntity? _selectedExchange;
  ChatRoomEntity? _plannerRoom;
  AppScreen _scheduleReturnTo = AppScreen.profile;
  AppScreen _exchangeReturnTo = AppScreen.home;
  UserEntity? _currentUser;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isLoggedIn = false;
  bool _restoringSession = true;

  // ── Getters ──────────────────────────────────────────────────────────────

  AppScreen get currentScreen  => _currentScreen;
  MaterialEntity? get selectedMaterial => _selectedMaterial;

  /// The order shown on the confirmation and complete-exchange screens.
  ExchangeEntity? get selectedExchange => _selectedExchange;

  /// The chat the meeting planner proposes into.
  ChatRoomEntity? get plannerRoom => _plannerRoom;
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

  // ── Orders & meetups ──────────────────────────────────────────────────────

  /// Orders [material] and shows the confirmation. Returns an error message, or `null`.
  Future<String?> buy(MaterialEntity material) async {
    final me = _currentUser;
    if (me == null) return 'Log in to buy.';
    try {
      final exchange = await account.order(material, buyerId: me.id);
      // The listing is reserved now; refresh so it stops showing as available.
      marketplace.load();
      _selectedExchange = exchange;
      navigateTo(AppScreen.confirmation);
      return null;
    } on DataException catch (e) {
      return e.message;
    }
  }

  /// Opens the chat with the other side of [exchange] to agree on the meetup.
  Future<String?> arrangeMeetup(ExchangeEntity exchange) async {
    try {
      final room = await chats.openRoomFor(exchange.materialId);
      openChat(room.id);
      return null;
    } on DataException catch (e) {
      return e.message;
    }
  }

  void openCompleteExchange(ExchangeEntity exchange) {
    _selectedExchange = exchange;
    // From the "Order Placed" screen there is nothing to go back to.
    _exchangeReturnTo = _currentScreen == AppScreen.confirmation ? AppScreen.home : _currentScreen;
    navigateTo(AppScreen.completeExchange);
  }

  void closeCompleteExchange() => navigateTo(_exchangeReturnTo);

  void openMeetingPlanner(ChatRoomEntity room) {
    _plannerRoom = room;
    navigateTo(AppScreen.meetingPlanner);
  }

  /// A fresh planner for [plannerRoom]; the screen owns and disposes it.
  MeetingPlannerState createMeetingPlanner(ChatRoomEntity room) =>
      MeetingPlannerState(useCases: meetups, chatRoomId: room.id);

  /// Back from the planner to the chat it was opened from.
  void closeMeetingPlanner() {
    navigateTo(AppScreen.messages);
    chats.refreshMessages();
  }

  /// Opens the class schedule; its back button returns to [returnTo].
  void openSchedule({AppScreen returnTo = AppScreen.profile}) {
    _scheduleReturnTo = returnTo;
    navigateTo(AppScreen.schedule);
  }

  void closeSchedule() => navigateTo(_scheduleReturnTo);

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
    schedule.load();
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
    schedule.clear();
    _selectedExchange = null;
    _plannerRoom = null;
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
    schedule.dispose();
    super.dispose();
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

