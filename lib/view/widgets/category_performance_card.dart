import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../model/entities/category_performance.dart';
import '../../view_model/category_performance_view_model.dart';
import 'common_widgets.dart';
import 'formatters.dart';

/// BQ6: which categories get the most listings and the most completed exchanges, one bar per
/// category. Loading, empty, the saved copy (marked as such while offline) and an error with
/// "Try again" are all drawn here; it only reacts to [viewModel]. It loads once when first shown;
/// the Seller Hub refreshes it together with its other figures.
class CategoryPerformanceCard extends StatefulWidget {
  final CategoryPerformanceViewModel viewModel;

  const CategoryPerformanceCard({super.key, required this.viewModel});

  @override
  State<CategoryPerformanceCard> createState() => _CategoryPerformanceCardState();
}

class _CategoryPerformanceCardState extends State<CategoryPerformanceCard> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = _Palette(
      txPrimary: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      txMuted: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      accentHi: dark ? AppColors.darkAccentHi : AppColors.lightAccentHi,
      track: dark ? AppColors.darkElevated : AppColors.lightElevated,
      error: dark ? AppColors.darkError : AppColors.lightError,
      warning: dark ? AppColors.darkWarning : AppColors.lightWarning,
      success: dark ? AppColors.darkSuccess : AppColors.lightSuccess,
    );

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final report = vm.report;
        final Widget body;
        if (report != null && report.items.isNotEmpty) {
          body = _Figures(viewModel: vm, palette: palette);
        } else if (report != null) {
          body = _Note(
            key: const Key('category-performance-empty'),
            icon: Icons.inventory_2_outlined,
            text: 'No listings yet. Categories appear here once students start selling.',
            palette: palette,
          );
        } else if (vm.error != null && !vm.isLoading) {
          body = _ErrorMessage(message: vm.error!, onRetry: () => vm.load(force: true), palette: palette);
        } else {
          body = _Loading(palette: palette);
        }

        return Semantics(
          container: true,
          label: 'Category performance: listings and completed exchanges per category',
          child: AppCard(
            key: const Key('category-performance-card'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.category_outlined, color: palette.accentHi, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top Categories',
                        style: AppTextStyles.body(palette.txPrimary,
                            fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text('Listings · swaps', style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs)),
                  ],
                ),
                if (vm.isSavedCopy && vm.savedAt != null) ...[
                  const SizedBox(height: 8),
                  _SavedCopyNote(savedAt: vm.savedAt!, refreshing: vm.isLoading, palette: palette),
                ],
                const SizedBox(height: 10),
                AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Palette {
  final Color txPrimary, txMuted, accentHi, track, error, warning, success;

  const _Palette({
    required this.txPrimary,
    required this.txMuted,
    required this.accentHi,
    required this.track,
    required this.error,
    required this.warning,
    required this.success,
  });
}

class _Figures extends StatelessWidget {
  final CategoryPerformanceViewModel viewModel;
  final _Palette palette;

  const _Figures({required this.viewModel, required this.palette});

  @override
  Widget build(BuildContext context) {
    final highest = viewModel.highestListings;
    return Column(
      key: const Key('category-performance-figures'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in viewModel.categories)
          _CategoryRow(category: category, highest: highest, palette: palette),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryPerformance category;
  final int highest;
  final _Palette palette;

  const _CategoryRow({required this.category, required this.highest, required this.palette});

  @override
  Widget build(BuildContext context) {
    final percent = (category.completionRate * 100).round();
    return Semantics(
      label: '${category.displayName}: ${category.totalListings} listings, '
          '${category.completedExchanges} completed exchanges, $percent percent completed',
      excludeSemantics: true,
      child: Padding(
        key: Key('category-performance-row-${category.category}'),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(category.displayName,
                      style: AppTextStyles.body(palette.txPrimary,
                          fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w600)),
                ),
                Text(
                  '${category.totalListings} listed · ${category.completedExchanges} swapped ($percent%)',
                  style: AppTextStyles.mono(palette.txMuted, fontSize: AppTextStyles.size2xs),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  LinearProgressIndicator(
                    value: highest == 0 ? 0 : category.totalListings / highest,
                    minHeight: 6,
                    backgroundColor: palette.track,
                    valueColor: AlwaysStoppedAnimation(palette.accentHi.withValues(alpha: 0.45)),
                  ),
                  LinearProgressIndicator(
                    value: highest == 0 ? 0 : category.completedExchanges / highest,
                    minHeight: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(palette.success),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Offline · saved 2h ago": the figures are the copy kept on the phone and may be outdated.
class _SavedCopyNote extends StatelessWidget {
  final DateTime savedAt;
  final bool refreshing;
  final _Palette palette;

  const _SavedCopyNote({required this.savedAt, required this.refreshing, required this.palette});

  @override
  Widget build(BuildContext context) {
    final age = timeAgo(savedAt);
    final text = refreshing
        ? 'Offline copy saved ${age.toLowerCase()} · refreshing…'
        : 'Offline copy · saved ${age.toLowerCase()}, may be outdated';
    return Semantics(
      liveRegion: true,
      label: refreshing
          ? 'Showing the copy saved ${age.toLowerCase()} while it refreshes'
          : 'The server could not be reached. Showing the copy saved ${age.toLowerCase()}; it may be outdated',
      excludeSemantics: true,
      child: Row(
        key: const Key('category-performance-saved-copy'),
        children: [
          Icon(Icons.cloud_off_rounded, color: palette.warning, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.body(palette.warning, fontSize: AppTextStyles.size2xs))),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final _Palette palette;

  const _Loading({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading category figures',
      excludeSemantics: true,
      child: Row(
        key: const Key('category-performance-loading'),
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: palette.accentHi),
          ),
          const SizedBox(width: 8),
          Text('Loading categories…', style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final _Palette palette;

  const _Note({super.key, required this.icon, required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: palette.txMuted, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs))),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final _Palette palette;

  const _ErrorMessage({required this.message, required this.onRetry, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('category-performance-error'),
      children: [
        Icon(Icons.cloud_off_rounded, color: palette.error, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(message, style: AppTextStyles.body(palette.txMuted, fontSize: AppTextStyles.size2xs)),
          ),
        ),
        Semantics(
          button: true,
          label: 'Try loading the category figures again',
          excludeSemantics: true,
          child: TextButton(
            key: const Key('category-performance-retry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: palette.accentHi,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
            ),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
