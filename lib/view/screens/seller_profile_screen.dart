import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../model/entities/material_entity.dart';
import '../../model/entities/rating_entity.dart';
import '../../model/entities/seller_profile_entity.dart';
import '../../model/entities/major_activity.dart';
import '../../model/entities/seller_reputation.dart';
import '../../view_model/seller_profile_view_model.dart';
import '../widgets/async_views.dart';
import '../widgets/cached_photo.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';
import '../widgets/saved_copy_banner.dart';

/// Public Seller Profile screen (Sprint 4 new view — mirrors Kotlin's `SellerProfileScreen`).
///
/// Displays seller identity, rating & listing counts, top 3 "Buyers say" tags, 5-to-1 star
/// distribution bars, campus-wide BQ 17 reputation benchmark, available listings, and reviews.
class SellerProfileScreen extends StatefulWidget {
  final SellerProfileViewModel Function() createViewModel;
  final VoidCallback onClose;
  final ValueChanged<MaterialEntity> onOpenMaterial;

  const SellerProfileScreen({
    super.key,
    required this.createViewModel,
    required this.onClose,
    required this.onOpenMaterial,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late final SellerProfileViewModel _vm = widget.createViewModel();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final profile = _vm.profile;
            return Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
                Container(
                  color: surface,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Semantics(
                        label: 'Go back',
                        button: true,
                        child: AppIconButton(
                          key: const Key('seller-profile-back'),
                          icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                          onTap: widget.onClose,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seller Profile',
                          style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd),
                        ),
                      ),
                      Semantics(
                        label: 'Refresh seller profile',
                        button: true,
                        child: AppIconButton(
                          key: const Key('seller-profile-refresh'),
                          icon: Icon(Icons.refresh_rounded, color: txSecondary, size: 18),
                          onTap: _vm.isLoading || _vm.isRefreshing ? null : _vm.refresh,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: border, height: 1),

                // ── Offline saved-copy notice ────────────────────────────────
                if (profile?.savedAt != null)
                  SavedCopyBanner(
                    savedAt: profile!.savedAt!,
                    onRetry: _vm.refresh,
                  ),

                // ── Body ─────────────────────────────────────────────────────
                Expanded(
                  child: _buildBody(context, profile, dark),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SellerProfileData? profile, bool dark) {
    if (_vm.isLoading && profile == null) {
      return const LoadingView();
    }

    if (_vm.error != null && profile == null) {
      if (_vm.isOfflineError) {
        return _OfflineEmptyState(
          onRetry: _vm.refresh,
          onBack: widget.onClose,
        );
      }
      return ErrorView(message: _vm.error!, onRetry: _vm.refresh);
    }

    if (profile == null) {
      return const LoadingView();
    }

    final summary = profile.summary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return RefreshIndicator(
      onRefresh: _vm.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _SellerHeaderCard(profile: profile),
          const SizedBox(height: 14),

          if (summary.topTags.isNotEmpty) ...[
            _BuyersSayCard(topTags: summary.topTags),
            const SizedBox(height: 14),
          ],

          _StarDistributionCard(summary: summary),
          const SizedBox(height: 14),

          if (profile.reputation != null && !profile.reputation!.isEmpty) ...[
            _ReputationInsightCard(
              reputation: profile.reputation!,
              averageRating: summary.averageRating,
              reviewCount: summary.reviewCount,
            ),
            const SizedBox(height: 14),
          ],
          if (profile.majorActivity != null && !profile.majorActivity!.isEmpty) ...[
            _MajorActivityCard(
              insight: profile.majorActivity!,
              sellerMajor: profile.seller.major,
              sellerFaculty: profile.seller.faculty,
            ),
            const SizedBox(height: 14),
          ],

          // ── Available Listings ──────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: SectionTitle('Available Listings')),
              Text(
                '${summary.availableListings.length}',
                style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.availableListings.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No active listings right now.',
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
              ),
            )
          else
            for (final item in summary.availableListings)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SellerListingCard(
                  material: item,
                  onTap: () => widget.onOpenMaterial(item),
                ),
              ),

          const SizedBox(height: 10),

          // ── Reviews ─────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: SectionTitle('Reviews')),
              Text(
                '${summary.reviewCount}',
                style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.reviews.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No reviews yet. Be the first to rate this seller after completing an exchange.',
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
              ),
            )
          else
            for (final review in summary.reviews)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReviewCard(review: review),
              ),
        ],
      ),
    );
  }
}

// ─── Header Card ──────────────────────────────────────────────────────────────

class _SellerHeaderCard extends StatelessWidget {
  final SellerProfileData profile;

  const _SellerHeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final seller = profile.seller;
    final summary = profile.summary;

    final subtitle = [
      if (seller.major.trim().isNotEmpty) seller.major.trim(),
      if (seller.faculty != null && seller.faculty!.trim().isNotEmpty) seller.faculty!.trim(),
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(initials: seller.initials, size: 60, outlined: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.fullName,
                      style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: accentHi, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          summary.reviewCount > 0
                              ? '${summary.averageRating.toStringAsFixed(1)} · ${summary.reviewCount} review${summary.reviewCount == 1 ? '' : 's'}'
                              : 'New seller · no reviews yet',
                          style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Available',
                  value: '${summary.activeListingsCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'Sold',
                  value: '${summary.soldListingsCount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'Listed',
                  value: '${summary.totalListingsCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final elevated = dark ? AppColors.darkElevated : AppColors.lightElevated;
    final border = dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
        ],
      ),
    );
  }
}

// ─── Buyers Say (Top 3 Tags) ──────────────────────────────────────────────────

class _BuyersSayCard extends StatelessWidget {
  final List<TagFrequency> topTags;

  const _BuyersSayCard({required this.topTags});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thumb_up_alt_outlined, color: accentHi, size: 16),
              const SizedBox(width: 6),
              Text(
                'Buyers say',
                style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in topTags)
                AppBadge('${tag.tag} (${tag.count})', highlighted: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 5-to-1 Star Distribution ─────────────────────────────────────────────────

class _StarDistributionCard extends StatelessWidget {
  final SellerProfileSummary summary;

  const _StarDistributionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final trackColor = dark ? AppColors.darkElevated : AppColors.lightElevated;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Breakdown',
            style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          for (final bucket in summary.starDistribution)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${bucket.stars}★',
                      style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bucket.fraction,
                        minHeight: 8,
                        backgroundColor: trackColor,
                        valueColor: AlwaysStoppedAnimation<Color>(accentHi),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${bucket.count}',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.sizeXs),
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

// ─── BQ 17 Campus Reputation Insight Card ─────────────────────────────────────

class _ReputationInsightCard extends StatelessWidget {
  final SellerReputationInsight reputation;
  final double averageRating;
  final int reviewCount;

  const _ReputationInsightCard({
    required this.reputation,
    required this.averageRating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    final starTier = reputation.starTierFor(
      averageRating: averageRating,
      reviewCount: reviewCount,
    );
    final reviewTier = reputation.reviewTierFor(reviewCount);
    final baseline = reputation.noReviewsBaseline;
    final activeTier = starTier ?? reviewTier;
    if (activeTier == null) return const SizedBox.shrink();

    final medianDaysText = activeTier.medianDaysToSell != null
        ? '${activeTier.medianDaysToSell!.toStringAsFixed(1)}d'
        : '—';

    return AppCard(
      key: const Key('bq17-reputation-card'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: accentHi, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Campus Reputation Benchmark',
                  style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
                ),
              ),
              AppBadge(activeTier.label, highlighted: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Across ${reputation.listingsTotal} campus listings, sellers in the "${activeTier.label}" tier get contacted on ${activeTier.contactRatePercent}% of items and sell ${activeTier.saleRatePercent}% of them.',
            style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Contact rate',
                  value: '${activeTier.contactRatePercent}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'Sale rate',
                  value: '${activeTier.saleRatePercent}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'Median sell',
                  value: medianDaysText,
                ),
              ),
            ],
          ),
          if (baseline != null && activeTier.group != baseline.group) ...[
            const SizedBox(height: 8),
            Text(
              'vs. new sellers (${baseline.label}): ${baseline.contactRatePercent}% contacted · ${baseline.saleRatePercent}% sold',
              style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
            ),
          ],
          if (reputation.savedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Benchmark saved ${timeAgo(reputation.savedAt!)}',
              style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Available Listing Row ────────────────────────────────────────────────────

class _SellerListingCard extends StatelessWidget {
  final MaterialEntity material;
  final VoidCallback onTap;

  const _SellerListingCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    return Semantics(
      label: 'Open listing ${material.title}, ${copPrice(material.price)}',
      button: true,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Row(
          children: [
            CachedPhoto(
              imageUrl: material.primaryImageUrl,
              category: material.category.name,
              width: 72,
              height: 72,
              borderRadius: BorderRadius.circular(10),
              memCacheWidth: CachedPhoto.thumbnailMemCacheWidth,
              maxWidthDiskCache: CachedPhoto.thumbnailDiskCacheWidth,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppBadge(material.conditionDisplayName),
                      if (material.courseCode != null && material.courseCode!.isNotEmpty)
                        AppBadge(material.courseCode!, highlighted: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copPrice(material.price),
                    style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm),
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

// ─── Review Card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final RatingEntity review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final raterName = review.rater?.fullName ?? 'Campus buyer';
    final raterInitials = review.rater?.initials ?? 'CB';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(initials: raterInitials, size: 34, outlined: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      timeAgo(review.createdAt),
                      style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var s = 1; s <= 5; s++)
                    Icon(
                      s <= review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 15,
                      color: s <= review.stars ? accentHi : txMuted,
                    ),
                ],
              ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in review.tags) AppBadge(tag),
              ],
            ),
          ],
          if (review.review != null && review.review!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.review!.trim(),
              style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Offline Empty State (never opened before) ────────────────────────────────

class _OfflineEmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;
  final VoidCallback onBack;

  const _OfflineEmptyState({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyView(
              icon: Icons.wifi_off_rounded,
              title: 'No internet connection',
              subtitle: "Connect to Wi-Fi or mobile data to view this seller's profile for the first time.",
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Retry', onPressed: onRetry),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onBack,
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BQ 18 Campus Activity by Major & Faculty Card ────────────────────────────

class _MajorActivityCard extends StatelessWidget {
  final MajorActivityInsight insight;
  final String sellerMajor;
  final String? sellerFaculty;

  const _MajorActivityCard({
    required this.insight,
    required this.sellerMajor,
    this.sellerFaculty,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    final matched = insight.activityForMajor(sellerMajor) ?? insight.topMajor;
    if (matched == null) return const SizedBox.shrink();
    final rank = insight.rankOfMajor(matched.name);
    final top = insight.topMajor;
    final facultyStats = insight.activityForFaculty(sellerFaculty ?? matched.faculty);

    final badgeText = rank != null ? '#$rank · ${matched.name}' : matched.name;

    return Semantics(
      label: 'Campus activity for ${matched.name}: ${matched.listings} listings, ${matched.buyerInquiries} inquiries, ${matched.completedExchanges} sold',
      child: AppCard(
        key: const Key('bq18-major-activity-card'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_outlined, color: accentHi, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Campus Activity by Major',
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(
                  child: AppBadge(badgeText, highlighted: true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Across ${insight.majorsActive} active majors on CampusSwap, ${matched.name} has ${matched.listings} listing${matched.listings == 1 ? '' : 's'}, ${matched.buyerInquiries} buyer inquir${matched.buyerInquiries == 1 ? 'y' : 'ies'}, and ${matched.conversionRatePercent}% listing-to-sale conversion.',
              style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    label: 'Listings',
                    value: '${matched.listings}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    label: 'Inquiries',
                    value: '${matched.buyerInquiries}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    label: 'Sold',
                    value: '${matched.completedExchanges}',
                  ),
                ),
              ],
            ),
            if (facultyStats != null && facultyStats.name != 'Unspecified') ...[
              const SizedBox(height: 8),
              Text(
                'Faculty (${facultyStats.name}): ${facultyStats.listings} listings · ${facultyStats.completedExchanges} sold (${facultyStats.conversionRatePercent}%)',
                style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
              ),
            ] else if (top != null && top.name != matched.name) ...[
              const SizedBox(height: 8),
              Text(
                'Top campus major: ${top.name} (${top.completedExchanges} sold)',
                style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
              ),
            ],
            if (insight.savedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Major activity saved ${timeAgo(insight.savedAt!)}',
                style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
              ),
            ],
          ],
        ),
      ),
    );
  }
}