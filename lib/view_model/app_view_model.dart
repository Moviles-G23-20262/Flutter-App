import 'package:flutter/material.dart';
import '../model/data_sources/local/draft_store.dart';
import '../model/data_sources/local/pending_listing_store.dart';
import '../model/entities/chat_room_entity.dart';
import '../model/entities/exchange_entity.dart';
import '../model/entities/enums.dart';
import '../model/entities/material_entity.dart';
import '../model/use_cases/meetup_use_cases.dart';
import '../model/entities/user_entity.dart';
import '../model/exceptions/data_exceptions.dart';
import 'account_view_model.dart';
import 'chat_view_model.dart';
import 'marketplace_view_model.dart';
import 'meeting_planner_view_model.dart';
import 'schedule_view_model.dart';
import 'power_view_model.dart';
import 'connectivity_view_model.dart';
import '../model/use_cases/track_event_use_case.dart';
import '../model/use_cases/outbox_use_cases.dart';
import '../model/use_cases/restore_session_use_case.dart';
import 'theme_view_model.dart';

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
class AppViewModel extends ChangeNotifier {
  /// Called after the user logs out, to clear the stored session.
  final Future<void> Function()? onLogout;

  /// Server-backed data; loaded on login and emptied on logout.
  final MarketplaceViewModel marketplace;
  final ChatViewModel chats;
  final AccountViewModel account;
  final ScheduleViewModel schedule;
  final MeetupUseCases meetups;

  /// Light/dark, including the automatic ambient-light mode.
  final ThemeViewModel theme;

  /// Battery saver; slows the chat refreshes down on a low battery.
  final PowerViewModel power;

  /// Online/offline, so screens can show an offline notice and sync again on reconnect.
  final ConnectivityViewModel connectivity;

  /// Telemetry for LISTING_VIEW and CONTACT_SELLER; never blocks or fails.
  final TrackEventUseCase trackEvent;

  /// The outbox: actions saved offline are sent while a user is signed in.
  final StartOutboxSyncUseCase? startOutboxSync;
  final StopOutboxSyncUseCase? stopOutboxSync;
  final SyncOutboxUseCase? syncOutbox;

  /// Checks a session that was opened offline once the server can be reached.
  final VerifySessionUseCase? verifySession;

  final DraftStore? draftStore;
  final PendingListingStore? pendingListingStore;

  AppViewModel({
    this.onLogout,
    required this.marketplace,
    required this.chats,
    required this.account,
    required this.schedule,
    required this.meetups,
    required this.theme,
    required this.power,
    required this.connectivity,
    required this.trackEvent,
    this.startOutboxSync,
    this.stopOutboxSync,
    this.syncOutbox,
    this.verifySession,
    this.draftStore,
    this.pendingListingStore,
  }) {
    // A theme change repaints the whole app, so it goes through the app-wide notifier.
    theme.addListener(notifyListeners);
    power.addListener(_applyPowerSaving);
    connectivity.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    marketplace.load();
    if (connectivity.isOnline) {
      _verifyOfflineSession();
      chats.setOffline(false);
    } else {
      chats.setOffline(true);
    }
  }

  /// A session restored offline shows the saved profile. Once the server answers, the profile is
  /// replaced by the fresh one and everything that could not load offline is loaded again.
  Future<void> _verifyOfflineSession() async {
    final verify = verifySession;
    if (verify == null || !_isLoggedIn) return;
    final fresh = await verify.execute();
    if (fresh == null || !_isLoggedIn || fresh.id != _currentUser?.id) return;
    _currentUser = fresh;
    notifyListeners();
    marketplace.load();
    chats.loadRooms();
    account.load();
    schedule.load();
  }

  void _applyPowerSaving() => chats.setPowerSaving(power.isSaving);

  AppScreen _currentScreen = AppScreen.login;
  MaterialEntity? _selectedMaterial;
  ExchangeEntity? _selectedExchange;
  ChatRoomEntity? _plannerRoom;
  AppScreen _scheduleReturnTo = AppScreen.profile;
  AppScreen _exchangeReturnTo = AppScreen.home;
  UserEntity? _currentUser;
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
  ThemeMode get themeMode      => theme.themeMode;
  bool get isLoggedIn          => _isLoggedIn;

  /// True until the startup attempt to restore a stored session has finished.
  bool get restoringSession    => _restoringSession;

  Brightness get brightness => theme.isDark ? Brightness.dark : Brightness.light;

  // ── Navigation ────────────────────────────────────────────────────────────

  void navigateTo(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void openMaterialDetail(MaterialEntity material) {
    // Opening someone else's listing is a view; looking at your own is not.
    if (_currentUser != null && material.sellerId != _currentUser?.id) {
      trackEvent.execute(AnalyticsEventType.LISTING_VIEW, materialId: material.id);
    }
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
  MeetingPlannerViewModel createMeetingPlanner(ChatRoomEntity room) =>
      MeetingPlannerViewModel(useCases: meetups, chatRoomId: room.id, userId: _currentUser?.id);

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
    account.watchPending(user.id);
    schedule.load();
    startOutboxSync?.execute(user.id);
  }

  /// The app came back to the foreground: send what was queued while it was in the background.
  void appResumed() {
    if (!_isLoggedIn) return;
    syncOutbox?.execute();
    _verifyOfflineSession();
  }

  /// "Message seller": opens (creating it if needed) the conversation about [material].
  /// Returns an error message to show the user, or `null` when the chat opened.
  Future<String?> messageSeller(MaterialEntity material) async {
    if (material.sellerId == _currentUser?.id) return 'This is your own listing.';
    try {
      final room = await chats.openRoomFor(material.id);
      trackEvent.execute(
        AnalyticsEventType.CONTACT_SELLER,
        materialId: material.id,
        metadata: {'chatRoomId': room.id},
      );
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
    stopOutboxSync?.execute();
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
    theme.removeListener(notifyListeners);
    theme.dispose();
    power.removeListener(_applyPowerSaving);
    power.dispose();
    connectivity.removeListener(_onConnectivityChanged);
    connectivity.dispose();
    super.dispose();
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  /// The sun/moon button: pins light or dark. Auto is chosen again in Profile → Appearance.
  void toggleTheme() => theme.toggle();
}
