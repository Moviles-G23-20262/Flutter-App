import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/async_views.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/user_summary.dart';

const kCategories = ['All', 'Books', 'Calculators', 'Lab Equipment', 'Furniture', 'Other'];

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final AppState appState;

  const HomeScreen({super.key, required this.appState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activeCategory = 'All';

  List<MaterialEntity> get _filtered {
    final available = widget.appState.marketplace.availableMaterials;
    if (_activeCategory == 'All') return available;
    return available.where((m) => m.category.displayName == _activeCategory).toList();
  }

  Future<void> _toggleFav(String materialId) async {
    final error = await widget.appState.marketplace.toggleFavorite(materialId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _messageSeller(MaterialEntity material) async {
    final error = await widget.appState.messageSeller(material);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _refresh() => Future.wait([
        widget.appState.marketplace.load(),
        widget.appState.account.load(),
      ]);

  /// Sellers with the most available items, computed from the listings themselves.
  List<_FeaturedSeller> _featuredSellers() {
    final bySeller = <String, _FeaturedSeller>{};
    for (final m in widget.appState.marketplace.availableMaterials) {
      final seller = m.seller;
      if (seller == null) continue;
      final current = bySeller[seller.id];
      bySeller[seller.id] = _FeaturedSeller(seller, (current?.items ?? 0) + 1);
    }
    final sellers = bySeller.values.toList()
      ..sort((a, b) {
        final byItems = b.items.compareTo(a.items);
        return byItems != 0 ? byItems : b.seller.rating.compareTo(a.seller.rating);
      });
    return sellers.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.appState.marketplace, widget.appState.account]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final market      = widget.appState.marketplace;
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final txPrimary   = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi    = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final offers      = _filtered;
    final recommended = offers.skip(4).take(3).toList();
    final sellers     = _featuredSellers();
    final unreadAlerts = widget.appState.account.unreadNotifications;

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CampusSwapLogo(size: 34, small: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Campus Swap',
                        style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                  ),
                  AppIconButton(
                    icon: Icon(
                      brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: txSecondary, size: 18,
                    ),
                    onTap: widget.appState.toggleTheme,
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppIconButton(
                        icon: Icon(Icons.notifications_outlined, color: txSecondary, size: 18),
                        onTap: () => widget.appState.navigateTo(AppScreen.notifications),
                      ),
                      if (unreadAlerts > 0)
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('$unreadAlerts',
                                style: AppTextStyles.mono(Colors.white, fontSize: AppTextStyles.size2xs)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icon(Icons.favorite_border_rounded, color: txSecondary, size: 18),
                    onTap: () => widget.appState.navigateTo(AppScreen.favorites),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Search bar (tappable, navigates to search screen)
              GestureDetector(
                onTap: () => widget.appState.navigateTo(AppScreen.search),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: txMuted, size: 18),
                      const SizedBox(width: 8),
                      Text('Search course materials…',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeSm)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        // ── Scrollable body ─────────────────────────────────────────────────
        Expanded(
          child: market.isFirstLoad && market.isLoading
              ? const LoadingView()
              : market.error != null && market.materials.isEmpty
                  ? ErrorView(message: market.error!, onRetry: market.load)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero banner
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _HeroBanner(
                                onBrowse: () => widget.appState.navigateTo(AppScreen.search),
                                brightness: brightness,
                              ),
                            ),

                            // Categories
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
                              child: SectionTitle('Categories'),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: kCategories.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => PillChip(
                                  label: kCategories[i],
                                  active: _activeCategory == kCategories[i],
                                  onTap: () => setState(() => _activeCategory = kCategories[i]),
                                ),
                              ),
                            ),

                            // Current Offers
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                              child: Row(
                                children: [
                                  Icon(Icons.local_fire_department_rounded, color: accentHi, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: SectionTitle('Current Offers')),
                                  TextButton(
                                    onPressed: () => widget.appState.navigateTo(AppScreen.search),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                    child: Row(
                                      children: [
                                        Text('See all', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                                        Icon(Icons.chevron_right_rounded, color: txMuted, size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (offers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: EmptyView(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Nothing listed yet',
                                  subtitle: _activeCategory == 'All'
                                      ? 'Be the first to list something with the Sell button.'
                                      : 'No items in $_activeCategory right now.',
                                ),
                              )
                            else
                              SizedBox(
                                height: 240,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: offers.take(4).length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                                  itemBuilder: (_, i) {
                                    final m = offers[i];
                                    return _ProductCard(
                                      material: m,
                                      isFav: market.isFavorite(m.id),
                                      onFavToggle: () => _toggleFav(m.id),
                                      onTap: () => widget.appState.openMaterialDetail(m),
                                      width: 155,
                                    );
                                  },
                                ),
                              ),

                            // Recommended
                            if (recommended.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                                child: Row(
                                  children: [
                                    Icon(Icons.menu_book_rounded, color: accentHi, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(child: SectionTitle('Recommended')),
                                    TextButton(
                                      onPressed: () => widget.appState.navigateTo(AppScreen.search),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                      child: Row(
                                        children: [
                                          Text('See all', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                                          Icon(Icons.chevron_right_rounded, color: txMuted, size: 14),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...recommended.map((m) => Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                    child: _RecommendedRow(
                                      material: m,
                                      onTap: () => widget.appState.openMaterialDetail(m),
                                      onMessage: () => _messageSeller(m),
                                    ),
                                  )),
                            ],

                            // Featured sellers
                            if (sellers.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                child: Row(
                                  children: [
                                    Icon(Icons.star_rounded, color: accentHi, size: 16),
                                    const SizedBox(width: 6),
                                    SectionTitle('Featured Sellers'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 140,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: sellers.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (_, i) => _SellerCard(
                                    name: sellers[i].seller.fullName,
                                    initials: sellers[i].seller.initials,
                                    rating: sellers[i].seller.rating,
                                    items: sellers[i].items,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FeaturedSeller {
  final UserSummary seller;
  final int items;

  const _FeaturedSeller(this.seller, this.items);
}

// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final VoidCallback onBrowse;
  final Brightness brightness;

  const _HeroBanner({required this.onBrowse, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.heroGradient(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Text('Weekly Deal', style: AppTextStyles.body(Colors.white.withValues(alpha: 0.9), fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Save big on\ncourse materials',
              style: AppTextStyles.heading(Colors.white, fontSize: AppTextStyles.sizeMd)),
          const SizedBox(height: 6),
          Text('Buy from fellow students and save up to 70% on textbooks, calculators and more.',
              style: AppTextStyles.body(Colors.white.withValues(alpha: 0.8), fontSize: AppTextStyles.sizeXs),
              maxLines: 3),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Browse Materials', style: AppTextStyles.body(Colors.white, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final MaterialEntity material;
  final bool isFav;
  final VoidCallback onFavToggle;
  final VoidCallback onTap;
  final double width;

  const _ProductCard({
    required this.material,
    required this.isFav,
    required this.onFavToggle,
    required this.onTap,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final accentHi  = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated  = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width > 0 ? width : null,
        decoration: AppDecorations.productCard(brightness),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 110,
              child: material.primaryImageUrl.isNotEmpty
                  ? Image.network(material.primaryImageUrl, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, _, _) => Container(color: elevated, child: const Icon(Icons.image_outlined, size: 32)))
                  : Container(color: elevated, child: const Icon(Icons.image_outlined, size: 32)),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(material.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                      ),
                      GestureDetector(
                        onTap: onFavToggle,
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? accentHi : accentHi.withValues(alpha: 0.6),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppBadge(material.conditionDisplayName),
                  const SizedBox(height: 6),
                  Text('\$${material.price.toStringAsFixed(2)}',
                      style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RecommendedRow extends StatelessWidget {
  final MaterialEntity material;
  final VoidCallback onTap;
  final VoidCallback onMessage;

  const _RecommendedRow({
    required this.material,
    required this.onTap,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final accentHi  = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated  = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 68, height: 68,
              child: material.primaryImageUrl.isNotEmpty
                  ? Image.network(material.primaryImageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: elevated))
                  : Container(color: elevated),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  children: [
                    AppBadge(material.conditionDisplayName),
                    if (material.courseCode != null)
                      AppBadge(material.courseCode!, highlighted: true),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('\$${material.price.toStringAsFixed(2)}',
                          style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
                    ),
                    GestureDetector(
                      onTap: onMessage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text('Message', style: AppTextStyles.body(Colors.white, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────

class _SellerCard extends StatelessWidget {
  final String name;
  final String initials;
  final double rating;
  final int items;

  const _SellerCard({
    required this.name,
    required this.initials,
    required this.rating,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted   = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UserAvatar(initials: initials, size: 44, outlined: true),
          const SizedBox(height: 8),
          Text(name.split(' ').first,
              style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          StarRating(rating: rating),
          Text('$items items', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
        ],
      ),
    );
  }
}
