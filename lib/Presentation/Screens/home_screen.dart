import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';

// ─── Mock Data ────────────────────────────────────────────────────────────────

/// Sample listings used while the API layer is not yet wired.
final List<MaterialEntity> kMockMaterials = [
  MaterialEntity(
    id: '1', title: 'Casio fx-991EX Scientific Calculator',
    description: 'Barely used during one semester. No scratches, all buttons work perfectly. Comes with original case and manual.',
    courseCode: 'MATH 201', price: 18.00,
    condition: MaterialConditionEnum.LIKE_NEW, status: MaterialStatusEnum.AVAILABLE,
    imageUrls: ['https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=400&h=300&fit=crop&auto=format'],
    sellerId: 'user-ms', category: MaterialCategoryEnum.CALCULATORS,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ),
  MaterialEntity(
    id: '2', title: 'Organic Chemistry Textbook 12th Ed.',
    description: 'Used for CHEM 301. Some highlighting in chapters 3-5 but otherwise clean. All pages intact.',
    courseCode: 'CHEM 301', price: 24.50,
    condition: MaterialConditionEnum.GOOD, status: MaterialStatusEnum.AVAILABLE,
    imageUrls: ['https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400&h=300&fit=crop&auto=format'],
    sellerId: 'user-jr', category: MaterialCategoryEnum.BOOKS,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ),
  MaterialEntity(
    id: '3', title: 'Lab Coat Size M — Pristine',
    description: 'Standard white lab coat, size medium. Worn only a few times in BIO lab. Washed and ready.',
    courseCode: 'BIO 201', price: 12.00,
    condition: MaterialConditionEnum.LIKE_NEW, status: MaterialStatusEnum.AVAILABLE,
    imageUrls: ['https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?w=400&h=300&fit=crop&auto=format'],
    sellerId: 'user-ac', category: MaterialCategoryEnum.LAB_EQUIPMENT,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ),
  MaterialEntity(
    id: '4', title: 'Data Structures & Algorithms Book',
    description: 'Used for CS 301. Notes written in pencil (mostly erasable). Solid reference for algorithm interviews.',
    courseCode: 'CS 301', price: 20.00,
    condition: MaterialConditionEnum.GOOD, status: MaterialStatusEnum.AVAILABLE,
    imageUrls: ['https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=400&h=300&fit=crop&auto=format'],
    sellerId: 'user-lt', category: MaterialCategoryEnum.BOOKS,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ),
  MaterialEntity(
    id: '5', title: 'TI-84 Plus Graphing Calculator',
    description: 'TI-84 Plus in good working condition. Battery door has minor crack but functions perfectly.',
    courseCode: 'STAT 201', price: 35.00,
    condition: MaterialConditionEnum.GOOD, status: MaterialStatusEnum.AVAILABLE,
    imageUrls: ['https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=400&h=300&fit=crop&auto=format'],
    sellerId: 'user-sl', category: MaterialCategoryEnum.CALCULATORS,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ),
  MaterialEntity(
    id: '6', title: 'Engineering Drawing Set',
    description: 'Complete set with compass, protractor, and drafting pencils. Used for one semester.',
    courseCode: 'ENG 101', price: 9.00,
    condition: MaterialConditionEnum.FAIR, status: MaterialStatusEnum.AVAILABLE,
    imageUrls: ['https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=400&h=300&fit=crop&auto=format'],
    sellerId: 'user-km', category: MaterialCategoryEnum.OTHER,
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ),
];

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
  final Set<String> _favorites = {};

  void _toggleFav(String id) =>
      setState(() => _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id));

  List<MaterialEntity> get _filtered {
    if (_activeCategory == 'All') return kMockMaterials;
    return kMockMaterials
        .where((m) => m.category.displayName == _activeCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final txPrimary   = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi    = brightness == Brightness.dark ? AppColors.darkAccentHi    : AppColors.lightAccentHi;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                  AppIconButton(
                    icon: Icon(Icons.notifications_outlined, color: txSecondary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icon(Icons.favorite_border_rounded, color: txSecondary, size: 18),
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
          child: SingleChildScrollView(
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
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.take(4).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final m = _filtered[i];
                      return _ProductCard(
                        material: m,
                        isFav: _favorites.contains(m.id),
                        onFavToggle: () => _toggleFav(m.id),
                        onTap: () => widget.appState.openMaterialDetail(m),
                        width: 155,
                      );
                    },
                  ),
                ),

                // Recommended
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
                ...kMockMaterials.skip(1).take(3).map((m) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _RecommendedRow(
                    material: m,
                    onTap: () => widget.appState.openMaterialDetail(m),
                    onMessage: () => widget.appState.navigateTo(AppScreen.messages),
                  ),
                )),

                // Featured sellers
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
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: const [
                      _SellerCard(name: 'Maria Santos', initials: 'MS', rating: 4.9, items: 8),
                      SizedBox(width: 10),
                      _SellerCard(name: 'Jake Reyes',   initials: 'JR', rating: 4.7, items: 5),
                      SizedBox(width: 10),
                      _SellerCard(name: 'Ana Cruz',     initials: 'AC', rating: 4.8, items: 12),
                      SizedBox(width: 10),
                      _SellerCard(name: 'Leo Tan',      initials: 'LT', rating: 4.6, items: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Text('Weekly Deal', style: AppTextStyles.body(Colors.white.withOpacity(0.9), fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Save big on\ncourse materials',
              style: AppTextStyles.heading(Colors.white, fontSize: AppTextStyles.sizeMd)),
          const SizedBox(height: 6),
          Text('Buy from fellow students and save up to 70% on textbooks, calculators and more.',
              style: AppTextStyles.body(Colors.white.withOpacity(0.8), fontSize: AppTextStyles.sizeXs),
              maxLines: 3),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                      errorBuilder: (_, __, ___) => Container(color: elevated, child: const Icon(Icons.image_outlined, size: 32)))
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
                          color: isFav ? accentHi : accentHi.withOpacity(0.6),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppBadge(material.conditionDisplayName),
                  const SizedBox(height: 6),
                  Text('₱${material.price.toStringAsFixed(2)}',
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
                      errorBuilder: (_, __, ___) => Container(color: elevated))
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
                      child: Text('₱${material.price.toStringAsFixed(2)}',
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
