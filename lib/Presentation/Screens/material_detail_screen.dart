import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';
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
  final int  _imageIndex = 0;
  bool _openingChat = false;
  bool _buying = false;

  bool get _isFav => widget.appState.marketplace.isFavorite(widget.material.id);
  bool get _isMine => widget.material.sellerId == widget.appState.currentUser?.id;

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFav() async {
    final error = await widget.appState.marketplace.toggleFavorite(widget.material.id);
    if (error != null) _showMessage(error);
  }

  Future<void> _messageSeller() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    final error = await widget.appState.messageSeller(widget.material);
    if (!mounted) return;
    setState(() => _openingChat = false);
    if (error != null) _showMessage(error);
  }

  Future<void> _buy() async {
    if (_buying) return;
    final m = widget.material;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buy this item?'),
        content: Text(
          '${m.title} for ${copPrice(m.price)}.\n\n'
          'It will be reserved for you. You pay in person when you meet '
          '${m.seller?.fullName.split(' ').first ?? 'the seller'} on campus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Place order')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _buying = true);
    final error = await widget.appState.buy(m);
    if (!mounted) return;
    setState(() => _buying = false);
    if (error != null) _showMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState.marketplace,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final m          = widget.material;
    final seller     = m.seller;
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
                                errorBuilder: (_, _, _) => Container(color: elevated))
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
                              colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
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
                                onTap: _toggleFav,
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
                                color: i == _imageIndex ? accentHi : Colors.white.withValues(alpha: 0.4),
                              ),
                            )),
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -16),
                    child: Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
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
                              Text(copPrice(m.price),
                                  style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeLg)),
                              const SizedBox(width: 14),
                              if (seller != null) StarRating(rating: seller.rating),
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
                                UserAvatar(initials: seller?.initials ?? '?', size: 42, outlined: true),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(seller?.fullName ?? 'Campus seller',
                                          style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.star_rounded, color: accentHi, size: 12),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              seller == null
                                                  ? 'Seller'
                                                  : '${seller.rating.toStringAsFixed(1)} · ${seller.major}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isMine)
                                GestureDetector(
                                  onTap: _messageSeller,
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
                          if (_isMine)
                            Text('This is your listing. Manage it from your Seller Hub.',
                                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs))
                          else ...[
                            if (!m.isAvailable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_clock_outlined, size: 15, color: txMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'This item is ${m.status.displayName.toLowerCase()}. You can still message the seller.',
                                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: SecondaryButton(
                                    label: _openingChat ? 'Opening…' : 'Message',
                                    leadingIcon: Icon(Icons.chat_bubble_outline_rounded, color: accentHi, size: 16),
                                    onPressed: _openingChat ? null : _messageSeller,
                                    fullWidth: true,
                                  ),
                                ),
                                if (m.isAvailable) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Buy now',
                                      leadingIcon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                                      onPressed: _buying ? null : _buy,
                                      isLoading: _buying,
                                      fullWidth: true,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
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

