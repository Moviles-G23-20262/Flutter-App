import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Strategies/sort_strategy.dart';
import 'home_screen.dart' show kMockMaterials;

// ─── Search Screen ────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  final AppState appState;

  const SearchScreen({super.key, required this.appState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  String _query       = '';
  _SearchFilters _filters = const _SearchFilters();

  List<MaterialEntity> get _results {
    var list = kMockMaterials.where((m) {
      if (_filters.category != null && m.category != _filters.category) return false;
      if (_filters.condition != null && m.condition != _filters.condition) return false;
      if (m.price > _filters.maxPrice) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return m.title.toLowerCase().contains(q) ||
               (m.courseCode?.toLowerCase().contains(q) ?? false) ||
               m.category.displayName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return _filters.sort.sort(list);
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
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface     : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder      : AppColors.lightBorder;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final results = _results;

    return Column(
      children: [
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
                    icon: Icon(Icons.photo_camera_outlined, color: txSecondary, size: 18),
                    onTap: () => widget.appState.navigateTo(AppScreen.newListingSmart),
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
          child: results.isEmpty
              ? _EmptySearch()
              : GridView.builder(
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Applied search filters (null category/condition means "All").
class _SearchFilters {
  static const double defaultMaxPrice = 200;

  final MaterialCategoryEnum? category;
  final MaterialConditionEnum? condition;
  final double maxPrice;
  final SortStrategy sort;

  const _SearchFilters({
    this.category,
    this.condition,
    this.maxPrice = defaultMaxPrice,
    this.sort = const RelevanceSortStrategy(),
  });

  bool get isActive =>
      category != null ||
      condition != null ||
      maxPrice < defaultMaxPrice ||
      sort.id != const RelevanceSortStrategy().id;
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
        _sort = kSortStrategies.first;
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

              _SheetLabel('Max Price: ₱${_maxPrice.toInt()}', color: txSecondary),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accentHi,
                  inactiveTrackColor: borderSub,
                  overlayColor: accent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  min: 5,
                  max: _SearchFilters.defaultMaxPrice,
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
                  for (final s in kSortStrategies)
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
    final elevated  = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;

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
              child: material.primaryImageUrl.isNotEmpty
                  ? Image.network(material.primaryImageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: elevated, child: const Icon(Icons.image_outlined)))
                  : Container(color: elevated, child: const Icon(Icons.image_outlined)),
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
                  StarRating(rating: 4.7, reviewCount: 8, iconSize: 12),
                  const SizedBox(height: 4),
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

