import 'package:flutter/material.dart';
import 'core/app_dependencies.dart';
import 'Presentation/State Management/account_state.dart';
import 'Presentation/State Management/app_state.dart';
import 'Presentation/State Management/chat_state.dart';
import 'Presentation/State Management/marketplace_state.dart';
import 'theme/app_theme.dart';
import 'Presentation/Screens/login_screen.dart';
import 'Presentation/Screens/register_screen.dart';
import 'Presentation/Screens/home_screen.dart';
import 'Presentation/Screens/search_screen.dart';
import 'Presentation/Screens/material_detail_screen.dart';
import 'Presentation/Screens/messages_screen.dart';
import 'Presentation/Screens/profile_screen.dart';
import 'Presentation/Screens/seller_hub_screen.dart';
import 'Presentation/Screens/new_listing_screen.dart';
import 'Presentation/Screens/new_listing_smart_screen.dart';
import 'Presentation/Screens/confirmation_screen.dart';
import 'Presentation/Screens/favorites_screen.dart';
import 'Presentation/Screens/notifications_screen.dart';
import 'Presentation/Widgets/common_widgets.dart';

void main() {
  runApp(const CampusSwapApp());
}

class CampusSwapApp extends StatefulWidget {
  const CampusSwapApp({super.key});

  @override
  State<CampusSwapApp> createState() => _CampusSwapAppState();
}

class _CampusSwapAppState extends State<CampusSwapApp> {
  final AppDependencies _deps = AppDependencies.create();
  late final AppState _appState = AppState(
    onLogout: _deps.logout.execute,
    marketplace: MarketplaceState(
      getMaterials: _deps.getMaterials,
      createListing: _deps.createListing,
      getWishlist: _deps.getWishlist,
      addToWishlist: _deps.addToWishlist,
      removeFromWishlist: _deps.removeFromWishlist,
    ),
    chats: ChatState(
      getChatRooms: _deps.getChatRooms,
      openChatRoom: _deps.openChatRoom,
      getMessages: _deps.getMessages,
      sendMessage: _deps.sendMessage,
      markRead: _deps.markChatRead,
    ),
    account: AccountState(
      getExchanges: _deps.getExchanges,
      getNotifications: _deps.getNotifications,
      markNotificationOpened: _deps.markNotificationOpened,
    ),
  );

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _deps.restoreSession.execute();
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
  void dispose() {
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
        return LoginScreen(appState: _appState, login: _deps.login);
      case AppScreen.register:
        return RegisterScreen(appState: _appState, registerStudent: _deps.registerStudent);
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
        return NewListingScreen(appState: _appState);
      case AppScreen.newListingSmart:
        return NewListingSmartScreen(appState: _appState);
      case AppScreen.confirmation:
        return ConfirmationScreen(appState: _appState);
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
  final AppState appState;
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
