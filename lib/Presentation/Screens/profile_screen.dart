import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/appearance_card.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';
import '../State Management/app_state.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final AppState appState;

  const ProfileScreen({super.key, required this.appState});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsOn    = true;
  bool _availableForChat   = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.appState.account, widget.appState.schedule]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final user       = widget.appState.currentUser;
    final account    = widget.appState.account;
    final purchases  = user == null ? const [] : account.purchasesOf(user.id);
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface    : AppColors.lightSurface;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder     : AppColors.lightBorder;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary: AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted  : AppColors.lightTextMuted;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi  : AppColors.lightAccentHi;
    final accent     = brightness == Brightness.dark ? AppColors.darkAccent     : AppColors.lightAccent;
    final accentLo   = brightness == Brightness.dark ? AppColors.darkAccentLo  : AppColors.lightAccentLo;
    final errorColor = brightness == Brightness.dark ? AppColors.darkError      : AppColors.lightError;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated   : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final shadow     = brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent;

    return Column(
      children: [
        // Header
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, color: accentHi, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Profile', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd))),
              AppIconButton(icon: Icon(Icons.edit_outlined, color: txSecondary, size: 18)),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile card
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: accentLo),
                              boxShadow: [BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Center(
                              child: Text(
                                user?.initials ?? '',
                                style: AppTextStyles.heading(Colors.white, fontSize: AppTextStyles.sizeMd),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.fullName ?? '',
                                    style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                                const SizedBox(height: 3),
                                Text(user?.email ?? '',
                                    style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('${user?.rating.toStringAsFixed(1) ?? '0.0'} rating',
                                        style: AppTextStyles.mono(accentHi, fontSize: AppTextStyles.sizeXs)),
                                    const SizedBox(width: 12),
                                    Text('${user == null ? 0 : account.swapCountOf(user.id)} swaps',
                                        style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Seller Hub',
                        leadingIcon: const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
                        onPressed: () => widget.appState.navigateTo(AppScreen.sellerHub),
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Academic info
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Academic Info'),
                  ],
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      _InfoRow(label: 'Faculty',  value: user?.faculty ?? 'Not set', isLast: false, brightness: brightness),
                      _InfoRow(label: 'Major',    value: user?.major   ?? 'Not set', isLast: true,  brightness: brightness),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Appearance (ambient light sensor)
                Row(
                  children: [
                    Icon(Icons.contrast_rounded, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Appearance'),
                  ],
                ),
                const SizedBox(height: 10),
                AppearanceCard(theme: widget.appState.theme),
                const SizedBox(height: 16),

                // Settings
                Row(
                  children: [
                    Icon(Icons.edit_outlined, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Profile Settings'),
                  ],
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        detail: 'Name, email, faculty and major',
                        brightness: brightness,
                      ),
                      _SettingsRow(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        detail: 'Messages, offers, handoff reminders',
                        trailing: _Toggle(
                          enabled: _notificationsOn,
                          onToggle: () => setState(() => _notificationsOn = !_notificationsOn),
                          brightness: brightness,
                        ),
                        brightness: brightness,
                      ),
                      _SettingsRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Chat Availability',
                        detail: 'Show sellers and buyers when you are reachable',
                        trailing: _Toggle(
                          enabled: _availableForChat,
                          onToggle: () => setState(() => _availableForChat = !_availableForChat),
                          brightness: brightness,
                        ),
                        brightness: brightness,
                      ),
                      _SettingsRow(
                        icon: Icons.calendar_month_outlined,
                        title: 'Class Schedule',
                        detail: widget.appState.schedule.blocks.isEmpty
                            ? 'Add your classes to get meetup time suggestions'
                            : '${widget.appState.schedule.blocks.length} classes · used to suggest meetup times',
                        onTap: widget.appState.openSchedule,
                        brightness: brightness,
                      ),
                      _SettingsRow(icon: Icons.account_balance_wallet_outlined, title: 'Payment Methods',    detail: 'GCash, Maya, cash preferences', brightness: brightness),
                      _SettingsRow(icon: Icons.location_on_outlined,            title: 'Meetup Locations',  detail: 'Saved handoff spots around campus', brightness: brightness),
                      _SettingsRow(icon: Icons.security_outlined,               title: 'Privacy and Safety', detail: 'Blocked users, report history, visibility', brightness: brightness),
                      _SettingsRow(icon: Icons.help_outline_rounded,            title: 'Help and Support',  detail: 'FAQs, dispute help', brightness: brightness, isLast: true),
                    ],
                  ),
                ),

                // Sign out
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: widget.appState.logout,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: elevated,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: Center(child: Icon(Icons.logout_rounded, color: errorColor, size: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sign Out', style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                              Text('End this session on the device', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Purchase History
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Purchase History'),
                  ],
                ),
                const SizedBox(height: 10),
                if (account.isFirstLoad && account.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else if (account.error != null && account.exchanges.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: account.load,
                      child: Text('${account.error}  Tap to retry.',
                          style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                    ),
                  )
                else if (purchases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Text('Nothing bought yet. Items you buy on Campus Swap will show up here.',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                    ),
                  ),
                ...purchases.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => widget.appState.openCompleteExchange(p),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56, height: 56,
                            child: (p.material?.primaryImageUrl ?? '').isNotEmpty
                                ? Image.network(p.material!.primaryImageUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                        color: elevated, child: const Icon(Icons.image_outlined)))
                                : Container(color: elevated, child: const Icon(Icons.image_outlined)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.material?.title ?? 'Item', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text('From ${p.seller?.fullName ?? 'a classmate'} · ${p.orderCode}${p.completedAt == null ? '' : ' · ${shortDate(p.completedAt!)}'}',
                                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: elevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderSubtle),
                                ),
                                child: Text(p.isPending ? 'Pending · tap to complete' : p.status.displayName,
                                    style: AppTextStyles.body(
                                        p.isPending
                                            ? accentHi
                                            : (brightness == Brightness.dark ? AppColors.darkSuccess : AppColors.lightSuccess),
                                        fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(copPrice(p.price),
                            style: AppTextStyles.mono(accentHi, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final Brightness brightness;

  const _InfoRow({required this.label, required this.value, required this.isLast, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final txMuted   = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final border    = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: border))),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
          const Spacer(),
          Text(value, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final Brightness brightness;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.trailing,
    this.onTap,
    this.isLast = false,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: border))),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: elevated,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: borderSubtle),
            ),
            child: Center(child: Icon(icon, color: accentHi, size: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: txSecondary, size: 15),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;
  final Brightness brightness;

  const _Toggle({required this.enabled, required this.onToggle, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final accent    = brightness == Brightness.dark ? AppColors.darkAccent    : AppColors.lightAccent;
    final accentLo  = brightness == Brightness.dark ? AppColors.darkAccentLo  : AppColors.lightAccentLo;
    final elevated  = brightness == Brightness.dark ? AppColors.darkElevated  : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txMuted   = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42, height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: enabled ? accent : elevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: enabled ? accentLo : borderSubtle),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : txMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
