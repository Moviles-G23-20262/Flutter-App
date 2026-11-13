import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import '../../app/theme/app_theme.dart';
import '../widgets/async_views.dart';
import '../widgets/cached_photo.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/recent_searches_view_model.dart';
import '../../model/entities/material_entity.dart';
import '../../model/strategies/sort_strategy.dart';

// ─── Search Screen ────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  final AppViewModel appState;

  const SearchScreen({super.key, required this.appState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _IndexedMaterial {
  final MaterialEntity material;
  final String titleLower;
  final String? courseLower;
  final String categoryLower;

  _IndexedMaterial(this.material)
      : titleLower = material.title.toLowerCase(),
        courseLower = material.courseCode?.toLowerCase(),
        categoryLower = material.category.displayName.toLowerCase();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  final ValueNotifier<String> _query = ValueNotifier<String>('');
  _SearchFilters _filters = _SearchFilters();
  late bool _wasOffline = widget.appState.connectivity.isOffline;

  List<MaterialEntity>? _indexedSource;
  List<_IndexedMaterial> _searchIndex = const [];

  List<MaterialEntity>? _cachedSource;
  String? _cachedQuery;
  MaterialCategoryEnum? _cachedCategory;
  MaterialConditionEnum? _cachedCondition;
  double? _cachedMaxPrice;
  String? _cachedSortId;
  List<MaterialEntity> _cachedResults = const [];

  List<MaterialEntity>? _observedAvailable;
  late bool _observedLoading = widget.appState.marketplace.isLoading;
  late bool _observedFirstLoad = widget.appState.marketplace.isFirstLoad;
  late String? _observedError = widget.appState.marketplace.error;
  late bool _observedEmpty = widget.appState.marketplace.materials.isEmpty;

  @override
  void initState() {
    super.initState();
    _observedAvailable = widget.appState.marketplace.availableMaterials;
    widget.appState.connectivity.addListener(_onConnectivityChanged);
    widget.appState.marketplace.addListener(_onMarketplaceChanged);
    // The recent searches are on the phone (Hive), so they load without a connection.
    _recent?.load(widget.appState.currentUser?.id);
  }

  RecentSearchesViewModel? get _recent => widget.appState.recentSearches;

  /// Puts a recent search back in the box; the results follow it.
  void _useRecentSearch(String query) {
    _queryCtrl.value = TextEditingValue(text: query, selection: TextSelection.collapsed(offset: query.length));
    _query.value = query;
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.connectivity.removeListener(_onConnectivityChanged);
      oldWidget.appState.marketplace.removeListener(_onMarketplaceChanged);
      widget.appState.connectivity.addListener(_onConnectivityChanged);
      widget.appState.marketplace.addListener(_onMarketplaceChanged);
      _syncObservedMarketplace();
    }
  }

  bool _syncObservedMarketplace() {
    final market = widget.appState.marketplace;
    final available = market.availableMaterials;
    final loading = market.isLoading;
    final firstLoad = market.isFirstLoad;
    final error = market.error;
    final empty = market.materials.isEmpty;
    final changed = !identical(available, _observedAvailable) ||
        loading != _observedLoading ||
        firstLoad != _observedFirstLoad ||
        error != _observedError ||
        empty != _observedEmpty;
    _observedAvailable = available;
    _observedLoading = loading;
    _observedFirstLoad = firstLoad;
    _observedError = error;
    _observedEmpty = empty;
    return changed;
  }

  void _onMarketplaceChanged() {
    // Ignore unrelated marketplace updates (such as wishlist toggles) that leave search state untouched.
    if (_syncObservedMarketplace() && mounted) {
      setState(() {});
    }
  }

  /// Back online after being offline: sync the listings again without the user asking.
  void _onConnectivityChanged() {
    final offline = widget.appState.connectivity.isOffline;
    final restored = _wasOffline && !offline;
    _wasOffline = offline;
    if (restored) widget.appState.marketplace.load();
    if (mounted) setState(() {});
  }

  List<_IndexedMaterial> _ensureIndex(List<MaterialEntity> available) {
    if (identical(available, _indexedSource)) return _searchIndex;
    _indexedSource = available;
    return _searchIndex = [for (final m in available) _IndexedMaterial(m)];
  }

  List<MaterialEntity> _computeResults(String query) {
    // Only spaces is no search: everything is shown, instead of the items with a space in their title.
    query = query.trim();
    final available = widget.appState.marketplace.availableMaterials;
    final sortId = _filters.sort.id;
    if (identical(available, _cachedSource) &&
        _cachedQuery == query &&
        _cachedCategory == _filters.category &&
        _cachedCondition == _filters.condition &&
        _cachedMaxPrice == _filters.maxPrice &&
        _cachedSortId == sortId) {
      return _cachedResults;
    }

    final indexed = _ensureIndex(available);
    final hasQuery = query.isNotEmpty;
    final q = hasQuery ? query.toLowerCase() : '';
    final cat = _filters.category;
    final cond = _filters.condition;
    final hasLimit = _filters.hasPriceLimit;
    final maxPrice = _filters.maxPrice;

    final list = <MaterialEntity>[];
    for (var i = 0; i < indexed.length; i++) {
      final entry = indexed[i];
      final m = entry.material;
      if (cat != null && m.category != cat) continue;
      if (cond != null && m.condition != cond) continue;
      if (hasLimit && m.price > maxPrice) continue;
      if (hasQuery) {
        final match = entry.titleLower.contains(q) ||
            (entry.courseLower?.contains(q) ?? false) ||
            entry.categoryLower.contains(q);
        if (!match) continue;
      }
      list.add(m);
    }

    _cachedSource = available;
    _cachedQuery = query;
    _cachedCategory = cat;
    _cachedCondition = cond;
    _cachedMaxPrice = maxPrice;
    _cachedSortId = sortId;

    // the ui simply executes the return
    return _cachedResults = _filters.sort.sort(list); // There is absolutely no if-else or switch statement cluttering the view
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
    widget.appState.marketplace.removeListener(_onMarketplaceChanged);
    _query.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market      = widget.appState.marketplace;
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      onChanged: (v) => _query.value = v,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => _recent?.record(v),
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
              ValueListenableBuilder<String>(
                valueListenable: _query,
                builder: (context, query, _) {
                  final count = _computeResults(query).length;
                  return Text('$count item${count != 1 ? 's' : ''} found',
                      style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs));
                },
              ),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        // ── Recent searches (saved on the phone, so they also show offline) ────────
        ListenableBuilder(
          listenable: Listenable.merge([_query, ?_recent]),
          builder: (context, _) {
            final recent = _recent;
            if (recent == null || recent.searches.isEmpty || _query.value.trim().isNotEmpty) return const SizedBox.shrink();
            return _RecentSearches(
              searches: recent.searches,
              onSelected: _useRecentSearch,
              onRemove: recent.forget,
              onClear: recent.clearAll,
            );
          },
        ),

        // ── Results grid ────────────────────────────────────────────────────
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              final results = _computeResults(query);
              return market.isFirstLoad && market.isLoading
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
                                    onTap: () {
                                      // Opening a result means the search was useful: remember it.
                                      _recent?.record(_query.value);
                                      widget.appState.openMaterialDetail(m);
                                    },
                                  );
                                },
                              ),
                            );
            },
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

/// The user's latest searches as chips: tap one to search it again, the cross forgets it.
class _RecentSearches extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const _RecentSearches({
    required this.searches,
    required this.onSelected,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Padding(
      key: const Key('recent-searches'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: txMuted, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Recent searches', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
              ),
              TextButton(
                key: const Key('clear-recent-searches'),
                onPressed: onClear,
                style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final query in searches)
                InputChip(
                  key: Key('recent-search-$query'),
                  label: Text(query, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs)),
                  onPressed: () => onSelected(query),
                  onDeleted: () => onRemove(query),
                  deleteIconColor: txMuted,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
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
  /// Image cache limits for the grid thumbnails (pixels).
  static const int _thumbnailMemCacheWidth = 400;
  static const int _thumbnailDiskCacheWidth = 800;

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
              // Grid thumbnails (about 120 px tall): resize before caching instead of keeping the
              // full photo. 400 px in memory is sharp on a phone grid; 800 px on disk leaves room
              // to open the same photo larger without downloading it again.
              child: CachedPhoto(
                imageUrl: material.primaryImageUrl,
                category: material.category.name,
                fit: BoxFit.cover,
                memCacheWidth: _thumbnailMemCacheWidth,
                maxWidthDiskCache: _thumbnailDiskCacheWidth,
              ),
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

