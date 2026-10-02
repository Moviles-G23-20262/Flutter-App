import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';

// ─── Seller Hub Screen ────────────────────────────────────────────────────────

class SellerHubScreen extends StatelessWidget {
  final AppState appState;

  const SellerHubScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState.marketplace, appState.chats, appState.account]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface    : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder     : AppColors.lightBorder;
    final txPrimary   = brightness == Brightness.dark ? AppColors.darkTextPrimary: AppColors.lightTextPrimary;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted  : AppColors.lightTextMuted;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accentHi    = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated    = brightness == Brightness.dark ? AppColors.darkElevated   : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final successColor= brightness == Brightness.dark ? AppColors.darkSuccess    : AppColors.lightSuccess;

    final me         = appState.currentUser;
    final myId       = me?.id ?? '';
    final myListings = appState.marketplace.listingsOf(myId);
    final activeCount = myListings.where((m) => m.isAvailable).length;
    final mySales    = appState.account.salesOf(myId).take(5).toList();
    // Conversations on my listings that already have a message from a buyer.
    final buyerChats = appState.chats.rooms
        .where((r) => r.sellerId == myId && r.lastMessage != null)
        .take(5)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
      children: [
        // Header
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              AppIconButton(
                icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                onTap: () => appState.navigateTo(AppScreen.profile),
              ),
              const SizedBox(width: 10),
              Icon(Icons.storefront_rounded, color: accentHi, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('My Seller Hub', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd))),
              GestureDetector(
                onTap: () => appState.navigateTo(AppScreen.newListing),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text('Add Item', style: AppTextStyles.body(Colors.white, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
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
                // Stats row
                Row(
                  children: [
                    _StatCard(icon: Icons.inventory_2_outlined, value: '$activeCount', label: 'Active Listings', brightness: brightness),
                    const SizedBox(width: 10),
                    _StatCard(icon: Icons.account_balance_wallet_outlined, value: '\$${appState.account.earnedThisMonth(myId).toStringAsFixed(0)}', label: 'Earned This Month', brightness: brightness),
                    const SizedBox(width: 10),
                    _StatCard(icon: Icons.trending_up_rounded, value: (me?.rating ?? 0).toStringAsFixed(1), label: 'Your Rating', brightness: brightness),
                  ],
                ),
                const SizedBox(height: 20),

                // Active listings
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('My Listings'),
                  ],
                ),
                const SizedBox(height: 10),
                if (myListings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Text('You have not listed anything yet. Tap "Add Item" to sell your first material.',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                    ),
                  ),
                ...myListings.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ListingRow(
                    material: m,
                    onTap: () => appState.openMaterialDetail(m),
                    brightness: brightness,
                    accentHi: accentHi,
                    elevated: elevated,
                    borderSubtle: borderSubtle,
                    txPrimary: txPrimary,
                    txMuted: txMuted,
                    successColor: successColor,
                  ),
                )),
                const SizedBox(height: 10),

                // Recent sales
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Recent Sales'),
                  ],
                ),
                const SizedBox(height: 10),
                if (mySales.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Text('No completed sales yet.',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                    ),
                  ),
                ...mySales.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.material?.title ?? 'Item', style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                              Text('Sold to ${s.buyer?.fullName ?? 'a classmate'} · ${s.completedAt == null ? '' : timeAgo(s.completedAt!)}',
                                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                            ],
                          ),
                        ),
                        Text('\$${s.price.toStringAsFixed(2)}',
                            style: AppTextStyles.mono(accentHi, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 10),

                // Buyer messages
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Buyer Messages'),
                  ],
                ),
                const SizedBox(height: 10),
                if (buyerChats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Text('No buyer messages yet.',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                    ),
                  ),
                ...buyerChats.map((room) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => appState.openChat(room.id),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(initials: room.buyer?.initials ?? '?', size: 28, outlined: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(room.buyer?.fullName ?? 'Campus user', style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                            ),
                            Text(timeAgo(room.lastActivity), style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Re: ${room.material?.title ?? 'your listing'}', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                        Text(room.lastMessage!.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Brightness brightness;

  const _StatCard({required this.icon, required this.value, required this.label, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted   = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi  = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;

    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: accentHi, size: 16),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
          ],
        ),
      ),
    );
  }
}

// ─── Listing Row ──────────────────────────────────────────────────────────────

class _ListingRow extends StatelessWidget {
  final MaterialEntity material;
  final VoidCallback onTap;
  final Brightness brightness;
  final Color accentHi, elevated, borderSubtle, txPrimary, txMuted, successColor;

  const _ListingRow({
    required this.material, required this.onTap,
    required this.brightness, required this.accentHi, required this.elevated,
    required this.borderSubtle, required this.txPrimary, required this.txMuted,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58, height: 58,
              child: material.primaryImageUrl.isNotEmpty
                  ? Image.network(material.primaryImageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: elevated))
                  : Container(color: elevated),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppBadge(material.conditionDisplayName),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('\$${material.price.toStringAsFixed(2)}',
                          style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: elevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Text(material.status.displayName,
                          style: AppTextStyles.body(material.isAvailable ? successColor : txMuted, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
