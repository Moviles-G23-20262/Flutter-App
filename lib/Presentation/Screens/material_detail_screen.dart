import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';

// ─── Material Detail Screen ───────────────────────────────────────────────────

class MaterialDetailScreen extends StatefulWidget {
  final AppState appState;
  final MaterialEntity material;

  const MaterialDetailScreen({
    super.key,
    required this.appState,
    required this.material,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  bool _isFav = false;
  int  _imageIndex = 0;

  // Related materials (same category, mock)
  List<MaterialEntity> _related(List<MaterialEntity> all) =>
      all.where((m) => m.category == widget.material.category && m.id != widget.material.id).take(3).toList();

  @override
  Widget build(BuildContext context) {
    final m          = widget.material;
    final brightness = Theme.of(context).brightness;
    final surface    = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final bg         = brightness == Brightness.dark ? AppColors.darkBg          : AppColors.lightBg;
    final txPrimary  = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary= brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final txMuted    = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi   = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;
    final elevated   = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final border     = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Hero image
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: m.primaryImageUrl.isNotEmpty
                            ? Image.network(m.primaryImageUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: elevated))
                            : Container(color: elevated, child: const Icon(Icons.image_outlined, size: 48)),
                      ),
                      // Gradient overlay
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Back + fav buttons
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppIconButton(
                                icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                                onTap: () => widget.appState.navigateTo(AppScreen.home),
                              ),
                              AppIconButton(
                                icon: Icon(
                                  _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: accentHi,
                                  size: 18,
                                ),
                                onTap: () => setState(() => _isFav = !_isFav),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Image dots
                      if (m.imageUrls.length > 1)
                        Positioned(
                          bottom: 12, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(m.imageUrls.length, (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _imageIndex ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i == _imageIndex ? accentHi : Colors.white.withOpacity(0.4),
                              ),
                            )),
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    margin: const EdgeInsets.only(top: -16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: [
                              AppBadge(m.category.displayName, highlighted: true),
                              if (m.courseCode != null) AppBadge(m.courseCode!),
                              AppBadge(m.conditionDisplayName),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Title
                          Text(m.title, style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                          const SizedBox(height: 8),

                          // Price + rating
                          Row(
                            children: [
                              Text('₱${m.price.toStringAsFixed(2)}',
                                  style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeLg)),
                              const SizedBox(width: 14),
                              const StarRating(rating: 4.8, reviewCount: 12),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Seller row
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: elevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: [
                                UserAvatar(initials: 'MS', size: 42, outlined: true),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Maria Santos',
                                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.star_rounded, color: accentHi, size: 12),
                                          const SizedBox(width: 3),
                                          Text('4.8 · 12 items sold · UP Student',
                                              style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => widget.appState.navigateTo(AppScreen.messages),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: txSecondary),
                                        const SizedBox(width: 5),
                                        Text('Chat', style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Description
                          Text('About this item',
                              style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeSm)),
                          const SizedBox(height: 8),
                          Text(m.description,
                              style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
                          const SizedBox(height: 24),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: SecondaryButton(
                                  label: _isFav ? 'Saved' : 'Save Item',
                                  leadingIcon: Icon(
                                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: accentHi, size: 16,
                                  ),
                                  onPressed: () => setState(() => _isFav = !_isFav),
                                  fullWidth: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PrimaryButton(
                                  label: 'Message Seller',
                                  leadingIcon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                                  onPressed: () => widget.appState.navigateTo(AppScreen.messages),
                                  fullWidth: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

