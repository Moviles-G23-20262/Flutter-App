import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../widgets/async_views.dart';
import '../widgets/cached_photo.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';
import '../../view_model/app_view_model.dart';
import '../../model/entities/material_entity.dart';
import '../../model/strategies/sort_strategy.dart';

// ─── Search Screen ────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  final AppViewModel appState;

  const SearchScreen({super.key, required this.appState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  String _query       = '';
  _SearchFilters _filters = _SearchFilters();
  late bool _wasOffline = widget.appState.connectivity.isOffline;

  @override
  void initState() {
    super.initState();
    widget.appState.connectivity.addListener(_onConnectivityChanged);
  }

  /// Back online after being offline: sync the listings again without the user asking.
  void _onConnectivityChanged() {
    final offline = widget.appState.connectivity.isOffline;
    final restored = _wasOffline && !offline;
    _wasOffline = offline;
    if (restored) widget.appState.marketplace.load();
  }

  List<MaterialEntity> get _results {
    var list = widget.appState.marketplace.availableMaterials.where((m) {
      if (_filters.category != null && m.category != _filters.category) return false;
      if (_filters.condition != null && m.condition != _filters.condition) return false;
      if (_filters.hasPriceLimit && m.price > _filters.maxPrice) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return m.title.toLowerCase().contains(q) ||
               (m.courseCode?.toLowerCase().contains(q) ?? false) ||
               m.category.displayName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // the ui simply executes the return
    return _filters.sort.sort(list); // There is absolutely no if-else or switch statement cluttering the view
    // ->>>>>>> The algorithmic logic is entirely decoupled.from the UI in sort_strategy.dart, between lines 6 and 112, 
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  @override
  void dispose() {
    widget.appState.connectivity.removeListener(_onConnectivityChanged);
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.appState.marketplace, widget.appState.connectivity]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final market      = widget.appState.marketplace;
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final results = _results;

    return Column(
      children: [
        // ── Offline notice ──────────────────────────────────────────────────
        if (widget.appState.connectivity.isOffline)
          _OfflineBanner(onRetry: market.isLoading ? null : market.load),

        // ── Header ─────────────────────────────────────────────────────────
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                    onTap: () => widget.appState.navigateTo(AppScreen.home),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      placeholder: 'Search course materials…',
                      controller: _queryCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      prefixIcon: Icon(Icons.search_rounded, color: txMuted, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icon(Icons.filter_alt_rounded,
                        color: _filters.isActive ? Colors.white : txSecondary, size: 18),
                    active: _filters.isActive,
                    onTap: _openFilters,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${results.length} item${results.length != 1 ? 's' : ''} found',
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        // ── Results grid ────────────────────────────────────────────────────
        Expanded(
          child: market.isFirstLoad && market.isLoading
              ? const LoadingView()
              : market.error != null && market.materials.isEmpty
                  ? ErrorView(message: market.error!, onRetry: market.load)
                  : results.isEmpty
              ? _EmptySearch()
              : RefreshIndicator(
                  onRefresh: market.load,
                  child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final m = results[i];
                    return _SearchProductCard(
                      material: m,
                      onTap: () => widget.appState.openMaterialDetail(m),
                    );
                  },
                ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Slim notice shown while the device has no network: search keeps working on the listings
/// already loaded. Disappears by itself when the connection returns.
class _OfflineBanner extends StatelessWidget {
  final Future<void> Function()? onRetry;

  const _OfflineBanner({this.onRetry});

  @override
  Widget build(BuildContext context) {
    final warning = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkWarning
        : AppColors.lightWarning;
    return Material(
      color: warning.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: warning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You're offline. Showing saved results.",
                key: const Key('offline-banner-text'),
                style: AppTextStyles.body(warning, fontSize: AppTextStyles.sizeXs),
              ),
            ),
            TextButton(
              key: const Key('offline-banner-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: warning,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Applied search filters (null category/condition means "All").
class _SearchFilters {
  /// Prices are in COP. The slider's top value means "any price", so nothing is hidden by default.
  static const double minPrice = 10000;
  static const double defaultMaxPrice = 1000000;
  static const int priceSteps = 99; // 10.000 COP each

  final MaterialCategoryEnum? category;
  final MaterialConditionEnum? condition;
  final double maxPrice;
  final SortStrategy sort;

  _SearchFilters({
    this.category,
    this.condition,
    this.maxPrice = defaultMaxPrice,
    SortStrategy? sort,
  }) : sort = sort ?? SortStrategyFactory.create(SortStrategyFactory.defaultKind);

  bool get hasPriceLimit => maxPrice < defaultMaxPrice;

  bool get isActive =>
      category != null ||
      condition != null ||
      hasPriceLimit ||
      sort.id != SortStrategyFactory.create(SortStrategyFactory.defaultKind).id;
}

// ─── Filter bottom sheet (View 06) ───────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final _SearchFilters initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MaterialCategoryEnum? _category = widget.initial.category;
  late MaterialConditionEnum? _condition = widget.initial.condition;
  late double _maxPrice = widget.initial.maxPrice;
  late SortStrategy _sort = widget.initial.sort;

  void _reset() => setState(() {
        _category = null;
        _condition = null;
        _maxPrice = _SearchFilters.defaultMaxPrice;
        _sort = SortStrategyFactory.create(SortStrategyFactory.defaultKind);
      });

  void _apply() => Navigator.of(context).pop(_SearchFilters(
        category: _category,
        condition: _condition,
        maxPrice: _maxPrice,
        sort: _sort,
      ));

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final surface     = isDark ? AppColors.darkSurface       : AppColors.lightSurface;
    final borderSub   = isDark ? AppColors.darkBorderSubtle  : AppColors.lightBorderSubtle;
    final txPrimary   = isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final txSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent      = isDark ? AppColors.darkAccent        : AppColors.lightAccent;
    final accentHi    = isDark ? AppColors.darkAccentHi      : AppColors.lightAccentHi;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: borderSub),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: borderSub, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text('Filters & Sort',
                        style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 8),

              _SheetLabel('Category', color: txSecondary),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PillChip(label: 'All', active: _category == null, onTap: () => setState(() => _category = null)),
                  for (final c in MaterialCategoryEnum.values)
                    PillChip(label: c.displayName, active: _category == c, onTap: () => setState(() => _category = c)),
                ],
              ),
              const SizedBox(height: 16),

              _SheetLabel('Condition', color: txSecondary),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PillChip(label: 'All', active: _condition == null, onTap: () => setState(() => _condition = null)),
                  for (final c in MaterialConditionEnum.values)
                    PillChip(label: c.displayName, active: _condition == c, onTap: () => setState(() => _condition = c)),
                ],
              ),
              const SizedBox(height: 16),

              _SheetLabel(
                'Max Price: ${_maxPrice >= _SearchFilters.defaultMaxPrice ? 'Any' : copPrice(_maxPrice)}',
                color: txSecondary,
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accentHi,
                  inactiveTrackColor: borderSub,
                  overlayColor: accent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  min: _SearchFilters.minPrice,
                  max: _SearchFilters.defaultMaxPrice,
                  divisions: _SearchFilters.priceSteps,
                  value: _maxPrice,
                  onChanged: (v) => setState(() => _maxPrice = v),
                ),
              ),
              const SizedBox(height: 8),

              _SheetLabel('Sort by', color: txSecondary),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in SortStrategyFactory.all)
                    PillChip(label: s.label, active: _sort.id == s.id, onTap: () => setState(() => _sort = s)),
                ],
              ),
              const SizedBox(height: 20),

              PrimaryButton(label: 'Apply Filters', fullWidth: true, onPressed: _apply),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SheetLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SearchProductCard extends StatelessWidget {
  final MaterialEntity material;
  final VoidCallback onTap;

  const _SearchProductCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txPrimary = brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final accentHi  = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.productCard(brightness),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CachedPhoto(imageUrl: material.primaryImageUrl, category: material.category.name, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (material.seller != null) ...[
                    StarRating(rating: material.seller!.rating, iconSize: 12),
                    const SizedBox(height: 4),
                  ],
                  AppBadge(material.conditionDisplayName),
                  const SizedBox(height: 6),
                  Text(copPrice(material.price),
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

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txMuted = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: borderSubtle),
          const SizedBox(height: 12),
          Text('No items found', style: AppTextStyles.heading(txMuted, fontSize: AppTextStyles.sizeMd)),
          const SizedBox(height: 4),
          Text('Try adjusting your filters', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
        ],
      ),
    );
  }
}

