import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../Domain/Entities/wishlist_item_entity.dart';
import '../State Management/app_state.dart';
import '../Widgets/async_views.dart';
import '../Widgets/common_widgets.dart';

// ─── Favorites Screen ─────────────────────────────────────────────────────────

class FavoritesScreen extends StatelessWidget {
  final AppState appState;

  const FavoritesScreen({super.key, required this.appState});

  Future<void> _unsave(BuildContext context, WishlistItemEntity item) async {
    final error = await appState.marketplace.toggleFavorite(item.materialId);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final dark        = brightness == Brightness.dark;
    final surface     = dark ? AppColors.darkSurface       : AppColors.lightSurface;
    final border      = dark ? AppColors.darkBorder        : AppColors.lightBorder;
    final txPrimary   = dark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final txMuted     = dark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accentHi    = dark ? AppColors.darkAccentHi      : AppColors.lightAccentHi;
    final elevated    = dark ? AppColors.darkElevated      : AppColors.lightElevated;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: appState.marketplace,
          builder: (context, _) {
            final market = appState.marketplace;
            // A saved listing that was deleted has no material left to show.
            final items = market.wishlist.where((w) => w.material != null).toList();

            return Column(
              children: [
                Container(
                  color: surface,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                        onTap: () => appState.navigateTo(AppScreen.home),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.favorite_rounded, color: accentHi, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Favorites', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd))),
                    ],
                  ),
                ),
                Divider(color: border, height: 1),
                Expanded(
                  child: market.isFirstLoad && market.isLoading
                      ? const LoadingView()
                      : market.error != null && market.wishlist.isEmpty
                          ? ErrorView(message: market.error!, onRetry: market.load)
                          : items.isEmpty
                              ? const EmptyView(
                                  icon: Icons.favorite_border_rounded,
                                  title: 'No favorites yet',
                                  subtitle: 'Tap the heart on a listing to save it here.',
                                )
                              : RefreshIndicator(
                                  onRefresh: market.load,
                                  child: ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final material = items[i].material!;
                                      return AppCard(
                                        padding: const EdgeInsets.all(12),
                                        onTap: () => appState.openMaterialDetail(material),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: SizedBox(
                                                width: 60, height: 60,
                                                child: material.primaryImageUrl.isNotEmpty
                                                    ? Image.network(material.primaryImageUrl, fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) => Container(color: elevated))
                                                    : Container(color: elevated, child: const Icon(Icons.image_outlined)),
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
                                                  Text(
                                                    material.isAvailable ? material.conditionDisplayName : material.status.displayName,
                                                    style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text('\$${material.price.toStringAsFixed(2)}',
                                                      style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _unsave(context, items[i]),
                                              child: Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Icon(Icons.favorite_rounded, color: accentHi, size: 20),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
