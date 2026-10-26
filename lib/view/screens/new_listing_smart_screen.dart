import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/formatters.dart';
import '../../view_model/app_view_model.dart';
import '../../model/entities/material_entity.dart';
import '../../view_model/smart_listing_view_model.dart';

// ─── Sell screen: the single "+ Sell" flow ───────────────────────────────────
//
// Top to bottom: category and condition, optional photos, smart pricing, listing details and
// Publish. MVVM: this View only renders SmartListingViewModel and forwards taps to it. The text
// controllers stay here because they are widget state; their text is handed to the ViewModel
// when publishing.

class NewListingSmartScreen extends StatefulWidget {
  final AppViewModel appState;

  /// Creates the ViewModel this screen owns (and disposes). Injected so the View never
  /// touches use cases or repositories.
  final SmartListingViewModel Function() viewModelFactory;

  const NewListingSmartScreen({
    super.key,
    required this.appState,
    required this.viewModelFactory,
  });

  @override
  State<NewListingSmartScreen> createState() => _NewListingSmartScreenState();
}

class _NewListingSmartScreenState extends State<NewListingSmartScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  late final SmartListingViewModel _viewModel = widget.viewModelFactory();

  /// One tap copies the ViewModel's suggested price into the price field.
  void _applySuggestion() {
    final price = _viewModel.suggestedPrice;
    if (price == null) return;
    _priceCtrl.text = price.round().toString();
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    final done = await _viewModel.publish(
      title: _titleCtrl.text,
      description: _descCtrl.text,
      courseCode: _courseCtrl.text,
      price: _priceCtrl.text,
    );
    if (!done || !mounted) return;
    // Let the "published" banner be seen, then show the seller's listings.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    widget.appState.navigateTo(AppScreen.sellerHub);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _courseCtrl.dispose();
    _priceCtrl.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildBody(context, _viewModel),
    );
  }

  Widget _buildBody(BuildContext context, SmartListingViewModel vm) {
    final brightness  = Theme.of(context).brightness;
    final isDark      = brightness == Brightness.dark;
    final bg          = isDark ? AppColors.darkBg            : AppColors.lightBg;
    final surface     = isDark ? AppColors.darkSurface       : AppColors.lightSurface;
    final border      = isDark ? AppColors.darkBorder        : AppColors.lightBorder;
    final borderSub   = isDark ? AppColors.darkBorderSubtle  : AppColors.lightBorderSubtle;
    final elevated    = isDark ? AppColors.darkElevated      : AppColors.lightElevated;
    final txPrimary   = isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final txSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted     = isDark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;
    final accentHi    = isDark ? AppColors.darkAccentHi      : AppColors.lightAccentHi;
    final success     = isDark ? AppColors.darkSuccess       : AppColors.lightSuccess;
    final errorColor  = isDark ? AppColors.darkError         : AppColors.lightError;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                    onTap: () => widget.appState.navigateTo(AppScreen.home),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.add_circle_outline_rounded, color: accentHi, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Sell an item',
                        style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                  ),
                ],
              ),
            ),
            Divider(color: border, height: 1),

            if (vm.published)
              Container(
                key: const Key('published-banner'),
                width: double.infinity,
                color: elevated,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: success, size: 15),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('"${_titleCtrl.text}" is ready for campus buyers.',
                          style: AppTextStyles.body(success, fontSize: AppTextStyles.sizeXs)),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── a) Category and condition ────────────────────────────
                  SectionTitle('Category', icon: Icon(Icons.category_outlined, color: txMuted, size: 16)),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in MaterialCategoryEnum.values)
                          PillChip(
                            label: c.displayName,
                            active: vm.selectedCategory == c.name,
                            onTap: () => vm.setCategory(c.name),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle('Condition', icon: Icon(Icons.label_outline_rounded, color: txMuted, size: 16)),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in MaterialConditionEnum.values)
                          PillChip(
                            label: c.displayName,
                            active: vm.selectedCondition == c.name,
                            onTap: () => vm.setCondition(c.name),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── b) Photos (optional) ─────────────────────────────────
                  SectionTitle('Photos', icon: Icon(Icons.photo_camera_outlined, color: txMuted, size: 16)),
                  const SizedBox(height: 4),
                  Text('Add at least 1 photo, up to ${SmartListingViewModel.maxPhotos}, with the camera or from the gallery.',
                      style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Camera',
                          leadingIcon: Icon(Icons.photo_camera_rounded, size: 16, color: txSecondary),
                          onPressed: vm.canAddPhoto ? () => vm.addPhoto(ImageSource.camera) : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Gallery',
                          leadingIcon: Icon(Icons.photo_library_rounded, size: 16, color: txSecondary),
                          onPressed: vm.canAddPhoto ? () => vm.addPhoto(ImageSource.gallery) : null,
                        ),
                      ),
                    ],
                  ),
                  if (vm.photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        key: const Key('photo-previews'),
                        scrollDirection: Axis.horizontal,
                        itemCount: vm.photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(vm.photos[i].bytes, width: 96, height: 96, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                key: Key('remove-photo-$i'),
                                onTap: () => vm.removePhoto(i),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (vm.isScanningPhoto)
                      Row(
                        key: const Key('scan-progress'),
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('Analysing photo…', style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('detect-category'),
                          onPressed: vm.canDetectCategory ? vm.detectCategoryFromPhoto : null,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                          label: const Text('Auto-detect category from photo'),
                          style: TextButton.styleFrom(
                            foregroundColor: accentHi,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28),
                            textStyle: AppTextStyles.body(accentHi, fontSize: AppTextStyles.sizeXs),
                          ),
                        ),
                      ),
                  ],
                  if (vm.detectedCategory != null || vm.photoMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      vm.detectedCategory != null
                          ? 'Detected: ${MaterialCategoryEnum.values.byName(vm.detectedCategory!).displayName}'
                          : vm.photoMessage!,
                      key: const Key('photo-scan-result'),
                      style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── c) Smart pricing (optional help: the price can be typed by hand) ──
                  Text('Not sure what to ask? Get a suggested price, or just type yours below.',
                      style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Suggest Fair Price',
                    fullWidth: true,
                    leadingIcon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    isLoading: vm.isLoading,
                    onPressed: vm.canEstimate ? vm.estimatePrice : null,
                  ),
                  if (vm.selectedCategory == null || vm.selectedCondition == null) ...[
                    const SizedBox(height: 6),
                    Text('To get a suggestion, choose a category and a condition first.',
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                  ],
                  if (vm.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(vm.errorMessage!,
                        key: const Key('estimate-error'),
                        style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                  ],
                  if (vm.hasEstimate) ...[
                    const SizedBox(height: 16),
                    _EstimateCard(viewModel: vm, onApply: _applySuggestion),
                  ],
                  const SizedBox(height: 20),

                  // ── d) Details ───────────────────────────────────────────
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Title', color: txMuted),
                        AppTextField(
                          key: const Key('listing-title'),
                          placeholder: 'e.g. Organic Chemistry Textbook',
                          controller: _titleCtrl,
                        ),
                        const SizedBox(height: 12),
                        _FieldLabel('Description', color: txMuted),
                        AppTextField(
                          key: const Key('listing-description'),
                          placeholder: 'Condition notes, what is included, meetup details…',
                          controller: _descCtrl,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Course Code', color: txMuted),
                                  AppTextField(
                                    key: const Key('listing-course'),
                                    placeholder: 'CS 301',
                                    controller: _courseCtrl,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Price (\$)', color: txMuted),
                                  AppTextField(
                                    key: const Key('smart-price-field'),
                                    placeholder: 'e.g. 35000',
                                    controller: _priceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Publish ──────────────────────────────────────────────────────
            Container(
              color: surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vm.publishError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderSub),
                      ),
                      child: Text(vm.publishError!,
                          key: const Key('publish-error'),
                          style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  PrimaryButton(
                    key: const Key('publish-listing'),
                    label: vm.isPublishing ? 'Publishing…' : 'Publish Listing',
                    fullWidth: true,
                    leadingIcon: vm.isPublishing ? null : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    isLoading: vm.isPublishing,
                    onPressed: (vm.isPublishing || vm.published) ? null : _publish,
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

// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _FieldLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
      );
}

class _EstimateCard extends StatelessWidget {
  final SmartListingViewModel viewModel;
  final VoidCallback onApply;

  const _EstimateCard({required this.viewModel, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final onHero     = AppColors.darkAccentTx;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.heroGradient(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommended price',
              style: AppTextStyles.body(onHero.withValues(alpha: 0.8), fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(copPrice(viewModel.suggestedPrice ?? 0),
              key: const Key('estimate-price'),
              style: AppTextStyles.mono(onHero, fontSize: AppTextStyles.sizeXl, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Fair range (p25–p75): ${copPrice(viewModel.p25 ?? 0)} – ${copPrice(viewModel.p75 ?? 0)}',
            key: const Key('estimate-range'),
            style: AppTextStyles.mono(onHero.withValues(alpha: 0.85), fontSize: AppTextStyles.sizeXs),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(viewModel.isFallback ? Icons.cloud_off_rounded : Icons.verified_rounded,
                  size: 14, color: onHero.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(viewModel.estimateSourceLabel,
                    key: const Key('estimate-source'),
                    style: AppTextStyles.body(onHero.withValues(alpha: 0.8), fontSize: AppTextStyles.size2xs)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            key: const Key('apply-suggested-price'),
            label: 'Apply this price',
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}
