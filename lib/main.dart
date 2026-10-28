import 'package:flutter/material.dart';
import 'app/app_dependencies.dart';
import 'view_model/account_view_model.dart';
import 'view_model/app_view_model.dart';
import 'view_model/login_view_model.dart';
import 'view_model/register_view_model.dart';
import 'view_model/chat_view_model.dart';
import 'view_model/marketplace_view_model.dart';
import 'view_model/schedule_view_model.dart';
import 'view_model/power_view_model.dart';
import 'view_model/connectivity_view_model.dart';
import 'view_model/theme_view_model.dart';
import 'view_model/complete_exchange_view_model.dart';
import 'app/theme/app_theme.dart';
import 'view/screens/login_screen.dart';
import 'view/screens/register_screen.dart';
import 'view/screens/home_screen.dart';
import 'view/screens/search_screen.dart';
import 'view/screens/material_detail_screen.dart';
import 'view/screens/messages_screen.dart';
import 'view/screens/profile_screen.dart';
import 'view/screens/seller_hub_screen.dart';
import 'view/screens/new_listing_smart_screen.dart';
import 'view/screens/complete_exchange_screen.dart';
import 'view/screens/confirmation_screen.dart';
import 'view/screens/meeting_point_screen.dart';
import 'view/screens/schedule_screen.dart';
import 'view/screens/favorites_screen.dart';
import 'view/screens/notifications_screen.dart';
import 'view/widgets/common_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  runApp(const CampusSwapApp());
}

class CampusSwapApp extends StatefulWidget {
  const CampusSwapApp({super.key});

  @override
  State<CampusSwapApp> createState() => _CampusSwapAppState();
}

class _CampusSwapAppState extends State<CampusSwapApp> with WidgetsBindingObserver {
  final AppDependencies _deps = AppDependencies.create();
  late final AppViewModel _appState = AppViewModel(
    onLogout: _deps.logout.execute,
    marketplace: MarketplaceViewModel(
      getMaterials: _deps.getMaterials,
      createListing: _deps.createListing,
      getWishlist: _deps.getWishlist,
      addToWishlist: _deps.addToWishlist,
      removeFromWishlist: _deps.removeFromWishlist,
      watchPendingListings: _deps.watchPendingListings,
      discardPendingListing: _deps.discardPendingListing,
    ),
    chats: ChatViewModel(
      getChatRooms: _deps.getChatRooms,
      openChatRoom: _deps.openChatRoom,
      getMessages: _deps.getMessages,
      sendMessage: _deps.sendMessage,
      markRead: _deps.markChatRead,
      answerProposal: _deps.meetups.answer,
      getConversationInsight: _deps.getConversationInsight,
      queueMessage: _deps.queueMessage,
      getPendingMessages: _deps.getPendingMessages,
      watchPendingCount: _deps.watchPendingCount,
      getChatAgreement: _deps.getChatAgreement,
      trackEvent: _deps.trackEvent,
    ),
    account: AccountViewModel(
      getExchanges: _deps.getExchanges,
      getNotifications: _deps.getNotifications,
      markNotificationOpened: _deps.markNotificationOpened,
      placeOrder: _deps.placeOrder,
      completeExchange: _deps.completeExchange,
      cancelExchange: _deps.cancelExchange,
      rateUser: _deps.rateUser,
      watchPendingActions: _deps.watchPendingActions,
      discardPendingAction: _deps.discardPendingAction,
    ),
    schedule: ScheduleViewModel(
      getSchedule: _deps.getSchedule,
      addBlock: _deps.addScheduleBlock,
      removeBlock: _deps.removeScheduleBlock,
    ),
    meetups: _deps.meetups,
    theme: ThemeViewModel(
      watchAmbientLight: _deps.watchAmbientLight,
      loadPreference: _deps.loadThemePreference,
      savePreference: _deps.saveThemePreference,
    ),
    power: PowerViewModel(watchBattery: _deps.watchBattery),
    trackEvent: _deps.trackEvent,
    connectivity: ConnectivityViewModel(
      getConnectivity: _deps.getConnectivity,
      watchConnectivity: _deps.watchConnectivity,
    ),
    startOutboxSync: _deps.startOutboxSync,
    stopOutboxSync: _deps.stopOutboxSync,
    syncOutbox: _deps.syncOutbox,
    verifySession: _deps.verifySession,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState.theme.start();
    _appState.power.start();
    _appState.connectivity.start();
    _deps.analyticsSync.start();
    _restoreSession();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> _restoreSession() async {
    // With a fingerprint enrolled and an account enrolled for it, the session is not restored by
    // itself: the login screen offers "Quick Unlock", which signs in after the sensor verifies the user.
    final lockedBehindFingerprint = await _deps.canQuickUnlock.execute() != null;
    final user = lockedBehindFingerprint ? null : await _deps.restoreSession.execute();
    if (!mounted) return;
    // From here on a rejected token means the session expired mid-use: sign out.
    _deps.apiClient.onUnauthorized = _appState.logout;
    if (user != null) {
      _appState.login(user);
    } else {
      _appState.sessionRestoreFinished();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _appState.appResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deps.analyticsSync.stop();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Campus Swap',
          debugShowCheckedModeBanner: false,
          themeMode: _appState.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: _buildScreen(),
        );
      },
    );
  }

  Widget _buildScreen() {
    if (_appState.restoringSession) return const _SplashScreen();

    switch (_appState.currentScreen) {
      case AppScreen.login:
        return LoginScreen(
          appState: _appState,
          createViewModel: () => LoginViewModel(
            login: _deps.login,
            canQuickUnlock: _deps.canQuickUnlock,
            quickUnlock: _deps.quickUnlock,
            forgetBiometrics: _deps.forgetBiometrics,
            onSignedIn: _appState.login,
          ),
        );
      case AppScreen.register:
        return RegisterScreen(
          appState: _appState,
          createViewModel: () => RegisterViewModel(
            registerStudent: _deps.registerStudent,
            onSignedIn: _appState.login,
            loadDraft: _deps.loadRegistrationDraft,
            saveDraft: _deps.saveRegistrationDraft,
            clearDraft: _deps.clearRegistrationDraft,
          ),
        );
      case AppScreen.materialDetail:
        return MaterialDetailScreen(
          appState: _appState,
          material: _appState.selectedMaterial!,
        );
      case AppScreen.favorites:
        return FavoritesScreen(appState: _appState);
      case AppScreen.notifications:
        return NotificationsScreen(appState: _appState);
      case AppScreen.sellerHub:
        return SellerHubScreen(appState: _appState);
      case AppScreen.newListing:
        return NewListingSmartScreen(
          appState: _appState,
          viewModelFactory: () => _deps.createSmartListingViewModel(
            publish: _appState.marketplace.publish,
            userId: _appState.currentUser?.id,
          ),
        );
      case AppScreen.confirmation:
        final order = _appState.selectedExchange;
        if (order == null) return AppShell(appState: _appState);
        return ConfirmationScreen(appState: _appState, exchange: order);
      case AppScreen.completeExchange:
        final exchange = _appState.selectedExchange;
        final me = _appState.currentUser;
        if (exchange == null || me == null) return AppShell(appState: _appState);
        final account = _appState.account;
        return CompleteExchangeScreen(
          appState: _appState,
          createViewModel: () => CompleteExchangeViewModel(
            exchange: exchange,
            userId: me.id,
            completeExchange: _deps.completeExchange,
            rateUser: _deps.rateUser,
            queueCompletion: _deps.queueExchangeCompletion,
            queueRating: _deps.queueRating,
            loadDraft: _deps.loadRatingDraft,
            saveDraft: _deps.saveRatingDraft,
            clearDraft: _deps.clearRatingDraft,
            onExchangeUpdated: account.updateExchange,
            completionQueued: account.isCompletionQueued(exchange.id),
            ratingQueued: account.isRatingQueued(exchange.id),
          ),
        );
      case AppScreen.meetingPlanner:
        final room = _appState.plannerRoom;
        if (room == null) return AppShell(appState: _appState);
        return MeetingPointScreen(appState: _appState, room: room);
      case AppScreen.schedule:
        return ScheduleScreen(appState: _appState);
      case AppScreen.home:
      case AppScreen.search:
      case AppScreen.messages:
      case AppScreen.profile:
        return AppShell(appState: _appState);
    }
  }
}

/// Shown while the stored session is being checked, so the login form doesn't flash.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CampusSwapLogo(size: 72)),
    );
  }
}

// ─── App Shell with custom bottom nav ────────────────────────────────────────

class AppShell extends StatelessWidget {
  final AppViewModel appState;
  const AppShell({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface   : AppColors.lightSurface;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder    : AppColors.lightBorder;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent    : AppColors.lightAccent;
    final accentLo   = brightness == Brightness.dark ? AppColors.darkAccentLo  : AppColors.lightAccentLo;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi  : AppColors.lightAccentHi;

    Widget child;
    int currentIndex;

    switch (appState.currentScreen) {
      case AppScreen.search:
        child = SearchScreen(appState: appState);
        currentIndex = 1;
        break;
      case AppScreen.messages:
        child = MessagesScreen(appState: appState);
        currentIndex = 2;
        break;
      case AppScreen.profile:
        child = ProfileScreen(appState: appState);
        currentIndex = 3;
        break;
      case AppScreen.home:
      default:
        child = HomeScreen(appState: appState);
        currentIndex = 0;
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NavTab(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: currentIndex == 0,
                  accentHi: accentHi,
                  txMuted: txMuted,
                  onTap: () => appState.navigateTo(AppScreen.home),
                ),
                _NavTab(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  active: currentIndex == 1,
                  accentHi: accentHi,
                  txMuted: txMuted,
                  onTap: () => appState.navigateTo(AppScreen.search),
                ),
                // ── Elevated "+ Sell" button ──
                GestureDetector(
                  onTap: () => appState.navigateTo(AppScreen.newListing),
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentLo),
                        boxShadow: [
                          BoxShadow(
                            color: brightness == Brightness.dark
                                ? AppColors.darkShadowAccent
                                : AppColors.lightShadowAccent,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          const Text(
                            'Sell',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _NavTab(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Messages',
                  active: currentIndex == 2,
                  accentHi: accentHi,
                  txMuted: txMuted,
                  onTap: () => appState.navigateTo(AppScreen.messages),
                ),
                _NavTab(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  active: currentIndex == 3,
                  accentHi: accentHi,
                  txMuted: txMuted,
                  onTap: () => appState.navigateTo(AppScreen.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Tab ─────────────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accentHi;
  final Color txMuted;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.accentHi,
    required this.txMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? accentHi : txMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
