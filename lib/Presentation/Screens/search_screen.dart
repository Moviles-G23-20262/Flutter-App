import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';
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
  String _category    = 'All';
  String _condition   = 'All';
  String _sortBy      = 'default';
  double _maxPrice    = 100;
  bool   _showFilters = false;

  static const _conditions = ['All', 'New', 'Like New', 'Good', 'Fair'];
  static const _categories = ['All', 'Books', 'Calculators', 'Lab Equipment', 'Other'];
  static const _sortOptions = [
    ['default', 'Relevance'],
    ['price-asc', 'Price low'],
    ['price-desc', 'Price high'],
  ];

  List<MaterialEntity> get _results {
    var list = kMockMaterials.where((m) {
      if (_category != 'All' && m.category.displayName != _category) return false;
      if (_condition != 'All' && m.conditionDisplayName != _condition) return false;
      if (m.price > _maxPrice) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return m.title.toLowerCase().contains(q) ||
               (m.courseCode?.toLowerCase().contains(q) ?? false) ||
               m.category.displayName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    if (_sortBy == 'price-asc')  list.sort((a, b) => a.price.compareTo(b.price));
    if (_sortBy == 'price-desc') list.sort((a, b) => b.price.compareTo(a.price));

    return list;
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
    final elevated    = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final borderSubtle = brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;

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
                    icon: Icon(Icons.tune_rounded, color: _showFilters ? Colors.white : txSecondary, size: 18),
                    active: _showFilters,
                    onTap: () => setState(() => _showFilters = !_showFilters),
                  ),
                ],
              ),

              // Filters panel
              if (_showFilters) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilterGroup(
                        label: 'Category',
                        options: _categories,
                        selected: _category,
                        onSelect: (v) => setState(() => _category = v),
                      ),
                      const SizedBox(height: 10),
                      _FilterGroup(
                        label: 'Condition',
                        options: _conditions,
                        selected: _condition,
                        onSelect: (v) => setState(() => _condition = v),
                      ),
                      const SizedBox(height: 10),
                      Text('Max Price: ₱${_maxPrice.toInt()}',
                          style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent,
                          thumbColor: brightness == Brightness.dark ? AppColors.darkAccentHi : AppColors.lightAccentHi,
                          inactiveTrackColor: borderSubtle,
                          overlayColor: (brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent).withOpacity(0.2),
                        ),
                        child: Slider(
                          min: 5, max: 200, value: _maxPrice,
                          onChanged: (v) => setState(() => _maxPrice = v),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _FilterGroup(
                        label: 'Sort by',
                        options: _sortOptions.map((e) => e[0]).toList(),
                        labels: _sortOptions.map((e) => e[1]).toList(),
                        selected: _sortBy,
                        onSelect: (v) => setState(() => _sortBy = v),
                      ),
                    ],
                  ),
                ),
              ],
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

class _FilterGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterGroup({
    required this.label,
    required this.options,
    this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(options.length, (i) {
            final val = options[i];
            final lbl = labels != null ? labels![i] : val;
            return PillChip(
              label: lbl,
              active: selected == val,
              onTap: () => onSelect(val),
            );
          }),
        ),
      ],
    );
  }
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
    final txMuted   = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
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

