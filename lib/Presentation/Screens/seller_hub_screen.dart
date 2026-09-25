import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';
import 'home_screen.dart' show kMockMaterials;

// ─── Seller Hub Screen ────────────────────────────────────────────────────────

class SellerHubScreen extends StatelessWidget {
  final AppState appState;

  const SellerHubScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
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

    // seller's listings (mock: use first seller)
    final myListings = kMockMaterials.take(2).toList();

    return Column(
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
                    _StatCard(icon: Icons.inventory_2_outlined, value: '8',    label: 'Active Listings', brightness: brightness),
                    const SizedBox(width: 10),
                    _StatCard(icon: Icons.account_balance_wallet_outlined, value: '₱240', label: 'Earned This Month', brightness: brightness),
                    const SizedBox(width: 10),
                    _StatCard(icon: Icons.trending_up_rounded, value: '4.9',   label: 'Your Rating', brightness: brightness),
                  ],
                ),
                const SizedBox(height: 20),

                // Active listings
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Active Listings'),
                  ],
                ),
                const SizedBox(height: 10),
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
                ..._kRecentSales.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                              Text('Sold to ${s.buyer} · ${s.date}',
                                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                            ],
                          ),
                        ),
                        Text('₱${s.price.toStringAsFixed(2)}',
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
                ..._kBuyerMessages.map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(initials: msg.initials, size: 28, outlined: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(msg.from, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                            ),
                            Text(msg.time, style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Re: ${msg.item}', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                        Text(msg.message, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
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
                      errorBuilder: (_, __, ___) => Container(color: elevated))
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
                    const SizedBox(width: 8),
                    Icon(Icons.visibility_outlined, size: 13, color: txMuted),
                    const SizedBox(width: 3),
                    Text('24 views', style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('₱${material.price.toStringAsFixed(2)}',
                          style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: elevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderSubtle),
                      ),
                      child: Text('Active',
                          style: AppTextStyles.body(successColor, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w500)),
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

// ─── Mock Data ────────────────────────────────────────────────────────────────

class _Sale { final String title, buyer, date; final double price; const _Sale({required this.title, required this.buyer, required this.date, required this.price}); }
class _BuyerMsg { final String from, initials, item, message, time; const _BuyerMsg({required this.from, required this.initials, required this.item, required this.message, required this.time}); }

const _kRecentSales = [
  _Sale(title: 'Casio fx-991EX Scientific Calculator', buyer: 'Ana Cruz', date: '2 days ago', price: 18.00),
  _Sale(title: 'Organic Chemistry Textbook 12th Ed.', buyer: 'Leo Tan',   date: '5 days ago', price: 24.50),
];

const _kBuyerMessages = [
  _BuyerMsg(from: 'Jake Reyes', initials: 'JR', item: 'Casio fx-991EX',   message: 'Is this still available?',    time: '2m ago'),
  _BuyerMsg(from: 'Sofia Lim',  initials: 'SL', item: 'Organic Chemistry', message: 'Can we meet at the library?', time: '1h ago'),
  _BuyerMsg(from: 'Leo Tan',    initials: 'LT', item: 'Lab Coat',           message: 'What size is this?',          time: '3h ago'),
];

