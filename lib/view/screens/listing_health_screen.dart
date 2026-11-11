import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../model/entities/dead_listings_insight.dart';
import '../../model/entities/pending_items.dart';
import '../../model/repositories/listing_health_preferences_repository.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/listing_health_view_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';
import '../widgets/offline_banner.dart';

// ─── Listing Health & Price-Drop Advisor Screen (BQ 10) ───────────────────────

class ListingHealthScreen extends StatefulWidget {
  final AppViewModel appState;
  final ListingHealthViewModel Function() createViewModel;

  const ListingHealthScreen({
    super.key,
    required this.appState,
    required this.createViewModel,
  });

  @override
  State<ListingHealthScreen> createState() => _ListingHealthScreenState();
}

class _ListingHealthScreenState extends State<ListingHealthScreen> {
  late final ListingHealthViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.createViewModel();
    _vm.initialize();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, widget.appState.connectivity]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevated = dark ? AppColors.darkElevated : AppColors.lightElevated;
    final borderSubtle = dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final successColor = dark ? AppColors.darkSuccess : AppColors.lightSuccess;
    final warningColor = dark ? AppColors.darkWarning : AppColors.lightWarning;
    final errorColor = dark ? AppColors.darkError : AppColors.lightError;

    final isOffline = widget.appState.connectivity.isOffline;
    final isWaitingForWifi = !isOffline && widget.appState.connectivity.isWaitingForWifi;
    final items = _vm.visibleAdvisories;
    final sellerSummary = _vm.sellerSummary;

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
                    onTap: () => widget.appState.navigateTo(AppScreen.sellerHub),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.monitor_heart_outlined, color: accentHi, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listing Health Advisor',
                          style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd),
                        ),
                        Text(
                          'Dead-listing patterns & smart price drops',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    key: const Key('listing-health-refresh'),
                    icon: _vm.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: accentHi),
                          )
                        : Icon(Icons.refresh_rounded, color: txSecondary, size: 18),
                    onTap: () => _vm.load(force: true),
                  ),
                ],
              ),
            ),
            Divider(color: border, height: 1),

            // Eventual connectivity banners
            if (_vm.isShowingCached)
              OfflineBanner.forCache(
                noun: 'health report',
                formattedAge: _vm.savedAt != null ? timeAgo(_vm.savedAt!) : null,
                onRetry: () => _vm.load(force: true),
              )
            else if (isOffline && _vm.usedLocalFallback)
              OfflineBanner(
                message: 'Offline mode: showing local risk analysis from saved listings.',
                onRetry: () => _vm.load(force: true),
              )
            else if (isOffline)
              OfflineBanner.forCache(
                noun: 'health report',
                formattedAge: null,
                onRetry: () => _vm.load(force: true),
              )
            else if (isWaitingForWifi)
              OfflineBanner.waitingForWifi(onSendNow: widget.appState.syncOverMobileData),

            if (_vm.statusMessage != null)
              Container(
                key: const Key('listing-health-status'),
                width: double.infinity,
                color: accentHi.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: accentHi),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _vm.statusMessage!,
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w500),
                      ),
                    ),
                    GestureDetector(
                      onTap: _vm.clearStatusMessage,
                      child: Icon(Icons.close_rounded, size: 16, color: txMuted),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _vm.isLoading && _vm.isFirstLoad
                  ? const Center(child: CircularProgressIndicator())
                  : _vm.error != null && items.isEmpty && !_vm.insight.hasData
                      ? _ErrorState(
                          message: _vm.error!,
                          txPrimary: txPrimary,
                          txMuted: txMuted,
                          onRetry: () => _vm.load(force: true),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _vm.load(force: true),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Stale threshold selector (SharedPreferences)
                              _StaleThresholdCard(
                                selectedDays: _vm.staleDays,
                                onSelectDays: _vm.changeStaleDays,
                                txPrimary: txPrimary,
                                txMuted: txMuted,
                                accentHi: accentHi,
                                elevated: elevated,
                                borderSubtle: borderSubtle,
                              ),
                              const SizedBox(height: 16),

                              // Seller & Market Health KPIs
                              Row(
                                children: [
                                  _MiniKpiCard(
                                    label: 'Dead (≥${_vm.staleDays}d)',
                                    value: '${sellerSummary?.deadListings ?? items.where((i) => i.isDead).length}',
                                    accent: errorColor,
                                    txPrimary: txPrimary,
                                    txMuted: txMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniKpiCard(
                                    label: 'At Risk',
                                    value: '${_vm.activeAdvisories.length}',
                                    accent: warningColor,
                                    txPrimary: txPrimary,
                                    txMuted: txMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniKpiCard(
                                    label: 'Market Dead Share',
                                    value: '${(_vm.summary.deadShare * 100).toStringAsFixed(0)}%',
                                    accent: accentHi,
                                    txPrimary: txPrimary,
                                    txMuted: txMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Survival checkpoints
                              if (_vm.survivalCurve.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.timeline_rounded, color: txMuted, size: 16),
                                    const SizedBox(width: 6),
                                    const SectionTitle('Unsold Survival Curve (BQ10)'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _SurvivalStrip(
                                  curve: _vm.survivalCurve,
                                  staleDays: _vm.staleDays,
                                  txPrimary: txPrimary,
                                  txMuted: txMuted,
                                  accentHi: accentHi,
                                  elevated: elevated,
                                  borderSubtle: borderSubtle,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // K-Means Hidden Pattern Clusters
                              if (_vm.clusters.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.hub_outlined, color: txMuted, size: 16),
                                    const SizedBox(width: 6),
                                    const SectionTitle('Hidden Stagnation Patterns'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 152,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _vm.clusters.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                                    itemBuilder: (context, index) => _ClusterCard(
                                      cluster: _vm.clusters[index],
                                      txPrimary: txPrimary,
                                      txSecondary: txSecondary,
                                      txMuted: txMuted,
                                      accentHi: accentHi,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],

                              // Advisories section header + dismissed filter
                              Row(
                                children: [
                                  Icon(Icons.tune_rounded, color: txMuted, size: 16),
                                  const SizedBox(width: 6),
                                  const Expanded(child: SectionTitle('Your Listings Advisor')),
                                  if (_vm.dismissedAdvisories.isNotEmpty)
                                    GestureDetector(
                                      key: const Key('toggle-dismissed-advisories'),
                                      onTap: () => _vm.setShowDismissed(!_vm.showDismissed),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _vm.showDismissed ? accentHi.withValues(alpha: 0.14) : elevated,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: _vm.showDismissed ? accentHi : borderSubtle),
                                        ),
                                        child: Text(
                                          _vm.showDismissed
                                              ? 'Hide ${_vm.dismissedAdvisories.length} dismissed'
                                              : 'Show ${_vm.dismissedAdvisories.length} dismissed',
                                          style: AppTextStyles.body(
                                            _vm.showDismissed ? accentHi : txSecondary,
                                            fontSize: AppTextStyles.size2xs,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (items.isEmpty)
                                AppCard(
                                  key: const Key('listing-health-empty'),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, color: successColor, size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _vm.dismissedAdvisories.isNotEmpty
                                              ? 'All active health tips are currently dismissed.'
                                              : 'All of your available listings look healthy! Keep photos clear and pricing near market median.',
                                          style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ListingHealthCard(
                                      item: item,
                                      isDismissed: _vm.isDismissed(item.id),
                                      isUpdating: _vm.isUpdating(item.id),
                                      pendingAction: _vm.pendingActionFor(item.id),
                                      isSimulatorOpen: _vm.simulatingListingId == item.id,
                                      simulatedPrice: _vm.simulatedPrice,
                                      simulation: _vm.simulatingListingId == item.id ? _vm.simulation : null,
                                      isSimulating: _vm.simulatingListingId == item.id && _vm.isSimulating,
                                      onToggleSimulator: () {
                                        if (_vm.simulatingListingId == item.id) {
                                          _vm.closeSimulator();
                                        } else {
                                          _vm.openSimulator(item);
                                        }
                                      },
                                      onSliderChanged: (val) => _vm.updateSimulatedPrice(item, val),
                                      onApplyDrop: (targetPrice) => _vm.applyPriceDrop(item, targetPrice),
                                      onToggleDismiss: () => _vm.toggleDismissAlert(item.id),
                                      onDiscardPending: () => _vm.discardQueuedPriceUpdate(item.id),
                                      txPrimary: txPrimary,
                                      txSecondary: txSecondary,
                                      txMuted: txMuted,
                                      accentHi: accentHi,
                                      elevated: elevated,
                                      borderSubtle: borderSubtle,
                                      successColor: successColor,
                                      warningColor: warningColor,
                                      errorColor: errorColor,
                                    ),
                                  ),
                                ),
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

class _StaleThresholdCard extends StatelessWidget {
  final int selectedDays;
  final Future<void> Function(int days) onSelectDays;
  final Color txPrimary, txMuted, accentHi, elevated, borderSubtle;

  const _StaleThresholdCard({
    required this.selectedDays,
    required this.onSelectDays,
    required this.txPrimary,
    required this.txMuted,
    required this.accentHi,
    required this.elevated,
    required this.borderSubtle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: accentHi),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Flag listing as dead after',
                  style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Saved locally',
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ListingHealthPreferencesRepository.allowedStaleDays.map((days) {
              final selected = days == selectedDays;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: days == ListingHealthPreferencesRepository.allowedStaleDays.last ? 0 : 8,
                  ),
                  child: GestureDetector(
                    key: Key('stale-days-$days'),
                    onTap: () => onSelectDays(days),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accentHi.withValues(alpha: 0.16) : elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? accentHi : borderSubtle),
                      ),
                      child: Center(
                        child: Text(
                          '${days}d',
                          style: AppTextStyles.mono(
                            selected ? accentHi : txPrimary,
                            fontSize: AppTextStyles.sizeXs,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniKpiCard extends StatelessWidget {
  final String label, value;
  final Color accent, txPrimary, txMuted;

  const _MiniKpiCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.txPrimary,
    required this.txMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextStyles.heading(accent, fontSize: AppTextStyles.sizeMd)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
          ],
        ),
      ),
    );
  }
}

class _SurvivalStrip extends StatelessWidget {
  final List<DeadSurvivalPoint> curve;
  final int staleDays;
  final Color txPrimary, txMuted, accentHi, elevated, borderSubtle;

  const _SurvivalStrip({
    required this.curve,
    required this.staleDays,
    required this.txPrimary,
    required this.txMuted,
    required this.accentHi,
    required this.elevated,
    required this.borderSubtle,
  });

  @override
  Widget build(BuildContext context) {
    final checkpoints = curve.where((p) => p.day == 7 || p.day == 14 || p.day == 30 || p.day == 60).toList();
    final shown = checkpoints.isNotEmpty ? checkpoints : curve.take(4).toList();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share of campus listings remaining unsold over time:',
            style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
          ),
          const SizedBox(height: 10),
          Row(
            children: shown.map((pt) {
              final highlight = pt.day == staleDays;
              final pct = (pt.survivalRate * 100).round();
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: pt == shown.last ? 0 : 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: highlight ? accentHi.withValues(alpha: 0.14) : elevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: highlight ? accentHi : borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Text('Day ${pt.day}', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                        const SizedBox(height: 2),
                        Text(
                          '$pct%',
                          style: AppTextStyles.mono(
                            highlight ? accentHi : txPrimary,
                            fontSize: AppTextStyles.sizeSm,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  final DeadListingCluster cluster;
  final Color txPrimary, txSecondary, txMuted, accentHi;

  const _ClusterCard({
    required this.cluster,
    required this.txPrimary,
    required this.txSecondary,
    required this.txMuted,
    required this.accentHi,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cluster.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                AppBadge('${(cluster.share * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${cluster.count} dead · ${cluster.avgPhotos.toStringAsFixed(1)} photos · ${cluster.avgDaysActive.toStringAsFixed(0)}d avg',
              style: AppTextStyles.mono(accentHi, fontSize: AppTextStyles.size2xs),
            ),
            const Spacer(),
            Text(
              cluster.recommendedAction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.size2xs),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingHealthCard extends StatelessWidget {
  final SellerListingHealthItem item;
  final bool isDismissed;
  final bool isUpdating;
  final PendingAction? pendingAction;
  final bool isSimulatorOpen;
  final double simulatedPrice;
  final PriceDropSimulation? simulation;
  final bool isSimulating;
  final VoidCallback onToggleSimulator;
  final ValueChanged<double> onSliderChanged;
  final Future<String?> Function(double targetPrice) onApplyDrop;
  final VoidCallback onToggleDismiss;
  final VoidCallback onDiscardPending;
  final Color txPrimary, txSecondary, txMuted, accentHi, elevated, borderSubtle, successColor, warningColor, errorColor;

  const _ListingHealthCard({
    required this.item,
    required this.isDismissed,
    required this.isUpdating,
    required this.pendingAction,
    required this.isSimulatorOpen,
    required this.simulatedPrice,
    required this.simulation,
    required this.isSimulating,
    required this.onToggleSimulator,
    required this.onSliderChanged,
    required this.onApplyDrop,
    required this.onToggleDismiss,
    required this.onDiscardPending,
    required this.txPrimary,
    required this.txSecondary,
    required this.txMuted,
    required this.accentHi,
    required this.elevated,
    required this.borderSubtle,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color riskColor;
    final String riskLabel;
    switch (item.riskLevel) {
      case 'high':
        riskColor = errorColor;
        riskLabel = item.isDead ? 'Dead · High Risk' : 'High Risk';
      case 'medium':
        riskColor = warningColor;
        riskLabel = 'Medium Risk';
      case 'watch':
        riskColor = accentHi;
        riskLabel = 'Watch';
      default:
        riskColor = successColor;
        riskLabel = 'Healthy';
    }

    final maxPrice = item.price > 0 ? item.price : 1.0;
    final minPrice = (maxPrice * 0.5).clamp(0.5, maxPrice);
    final clampedSlider = simulatedPrice.clamp(minPrice, maxPrice);

    return AppCard(
      key: Key('health-item-${item.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$riskLabel · ${item.riskScore}/100',
                  style: AppTextStyles.body(riskColor, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                copPrice(item.price),
                style: AppTextStyles.mono(accentHi, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
              ),
              if (item.categoryMedianPrice != null)
                Text(
                  'Market median: ${copPrice(item.categoryMedianPrice!)}',
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
                ),
              Text(
                '${item.daysActive.toStringAsFixed(0)}d active · ${item.photos} photos · ${item.contacts} msgs',
                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs),
              ),
            ],
          ),
          if (item.clusterLabel != null) ...[
            const SizedBox(height: 8),
            AppBadge('Pattern: ${item.clusterLabel}'),
          ],
          if (pendingAction != null) ...[
            const SizedBox(height: 8),
            Container(
              key: Key('pending-price-${item.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (pendingAction!.status == PendingStatus.refused ? errorColor : warningColor).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    pendingAction!.status == PendingStatus.refused
                        ? Icons.error_outline_rounded
                        : Icons.cloud_upload_outlined,
                    size: 15,
                    color: pendingAction!.status == PendingStatus.refused ? errorColor : warningColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pendingAction!.status == PendingStatus.refused
                          ? (pendingAction!.lastError ?? 'Queued price update was refused.')
                          : 'Price change queued offline · syncing automatically',
                      style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (pendingAction!.status == PendingStatus.refused)
                    TextButton(
                      onPressed: onDiscardPending,
                      child: const Text('Discard'),
                    ),
                ],
              ),
            ),
          ],
          if (item.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...item.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $r', style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.size2xs)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            item.recommendation,
            style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500),
          ),

          // Action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.suggestedPrice != null && item.suggestedPrice! < item.price) ...[
                Expanded(
                  child: FilledButton.icon(
                    key: Key('apply-suggested-${item.id}'),
                    onPressed: isUpdating ? null : () => onApplyDrop(item.suggestedPrice!),
                    icon: const Icon(Icons.trending_down_rounded, size: 16),
                    label: Text(
                      'Drop to ${copPrice(item.suggestedPrice!)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              OutlinedButton(
                key: Key('simulate-btn-${item.id}'),
                onPressed: onToggleSimulator,
                child: Text(isSimulatorOpen ? 'Hide What-If' : 'Simulate Drop'),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: Key('dismiss-btn-${item.id}'),
                tooltip: isDismissed ? 'Restore alert' : 'Dismiss alert',
                onPressed: onToggleDismiss,
                icon: Icon(
                  isDismissed ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                  size: 18,
                  color: txMuted,
                ),
              ),
            ],
          ),

          // Interactive Isolate-backed What-If Price Drop Simulator
          if (isSimulatorOpen) ...[
            const SizedBox(height: 10),
            Container(
              key: Key('simulator-panel-${item.id}'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'What-If Price Simulator',
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        copPrice(clampedSlider),
                        style: AppTextStyles.mono(accentHi, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    key: Key('simulator-slider-${item.id}'),
                    min: minPrice,
                    max: maxPrice,
                    value: clampedSlider,
                    onChanged: maxPrice > minPrice ? onSliderChanged : null,
                  ),
                  if (simulation != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Projected risk: ${simulation!.projectedRiskScore}/100 (${simulation!.riskReduction > 0 ? '-${simulation!.riskReduction} pts' : 'no change'})',
                            style: AppTextStyles.body(successColor, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (simulation!.estimatedSellDays != null)
                          Text(
                            '~${simulation!.estimatedSellDays!.toStringAsFixed(1)}d est.',
                            style: AppTextStyles.mono(txMuted, fontSize: AppTextStyles.size2xs),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      simulation!.summaryText,
                      style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.size2xs),
                    ),
                  ] else if (isSimulating)
                    Text('Calculating in worker isolate…', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      key: Key('apply-simulated-${item.id}'),
                      onPressed: isUpdating || clampedSlider >= item.price ? null : () => onApplyDrop(clampedSlider),
                      child: Text(isUpdating ? 'Updating…' : 'Apply ${copPrice(clampedSlider)}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Color txPrimary, txMuted;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.txPrimary,
    required this.txMuted,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: txMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
