import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../Widgets/formatters.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/use_cases/price_estimator_use_case.dart' show PriceEstimateSource;
import '../ViewModels/smart_listing_view_model.dart';

// ─── Smart New Listing Screen (camera + fair price estimate) ─────────────────

class NewListingSmartScreen extends StatefulWidget {
  final AppState appState;

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
  final _picker = ImagePicker();
  final _priceCtrl = TextEditingController();
  late final SmartListingViewModel _viewModel = widget.viewModelFactory();

  Uint8List? _imageBytes; // Instead, we compress the image and read it directly into memory as a Uint8List ->>> line 42

// Architecturally, we chose not to save this image to the device's physical storage to respect the user's space
// ->>>>>>> line 26
  Future<void> _pick(ImageSource source) async {
    try {
      // the _pick method directly invokes ImagePicker().pickImage using ImageSource.camera. ->>> line 31
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (_) {
      // If the OS denies camera permissions, our catch block gracefully handles the failure by displaying
      // a SnackBar, ensuring the app never crashes
      // ->>>>>>> lib/Domain/use_cases/price_estimator_use_case.dart, between lines 44 and 54, 
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access the camera or gallery. Check app permissions.')),
      );
    }
  }


  /// One tap copies the ViewModel's suggested price into the price field.
  void _applySuggestion() {
    final price = _viewModel.suggestedPrice;
    if (price == null) return;
    _priceCtrl.text = price.round().toString();
  }

  @override
  void dispose() {
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
    final elevated    = isDark ? AppColors.darkElevated      : AppColors.lightElevated;
    final borderSub   = isDark ? AppColors.darkBorderSubtle  : AppColors.lightBorderSubtle;
    final txPrimary   = isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final txSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final txMuted     = isDark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;

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
                    onTap: () => widget.appState.navigateTo(AppScreen.search),
                  ),
                  const SizedBox(width: 12),
                  Text('Smart Listing', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Photo preview ────────────────────────────────────────
                  Container(
                    height: 220,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: elevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderSub),
                    ),
                    child: _imageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_outlined, size: 40, color: txMuted),
                              const SizedBox(height: 8),
                              Text('Add a photo of your item',
                                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                            ],
                          )
                        : Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Camera',
                          leadingIcon: Icon(Icons.photo_camera_rounded, size: 16, color: txSecondary),
                          onPressed: () => _pick(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Gallery',
                          leadingIcon: Icon(Icons.photo_library_rounded, size: 16, color: txSecondary),
                          onPressed: () => _pick(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Category ─────────────────────────────────────────────
                  Text('Category',
                      style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in MaterialCategoryEnum.values)
                        PillChip(
                          label: c.displayName,
                          active: vm.selectedCategory == c.name,
                          onTap: () => vm.setCategory(c.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Condition ────────────────────────────────────────────
                  Text('Condition',
                      style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in MaterialConditionEnum.values)
                        PillChip(
                          label: c.displayName,
                          active: vm.selectedCondition == c.name,
                          onTap: () => vm.setCondition(c.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: 'Suggest Fair Price',
                    fullWidth: true,
                    leadingIcon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    isLoading: vm.isLoading,
                    onPressed: vm.canEstimate ? vm.estimatePrice : null,
                  ),

                  if (vm.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(vm.errorMessage!,
                        key: const Key('estimate-error'),
                        style: AppTextStyles.body(isDark ? AppColors.darkError : AppColors.lightError, fontSize: AppTextStyles.sizeXs)),
                  ],

                  if (vm.hasEstimate) ...[
                    const SizedBox(height: 16),
                    _EstimateCard(viewModel: vm, onApply: _applySuggestion),
                  ],
                  const SizedBox(height: 20),

                  // ── Price ────────────────────────────────────────────────
                  Text('Your price (COP)',
                      style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  AppTextField(
                    key: const Key('smart-price-field'),
                    placeholder: 'e.g. 35000',
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icon(Icons.attach_money_rounded, color: txMuted, size: 18),
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

class _EstimateCard extends StatelessWidget {
  final SmartListingViewModel viewModel;
  final VoidCallback onApply;

  const _EstimateCard({required this.viewModel, required this.onApply});

  String get _sourceLabel {
    switch (viewModel.source) {
      case PriceEstimateSource.realSales:
        final n = viewModel.sampleSize;
        return 'Based on $n real sale${n == 1 ? '' : 's'}';
      case PriceEstimateSource.lowSampleHeuristic:
        return 'Heuristic estimate, not enough sales yet';
      case PriceEstimateSource.offlineHeuristic:
      case null:
        return 'Heuristic estimate, no connection to sales data';
    }
  }

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
                child: Text(_sourceLabel,
                    key: const Key('estimate-source'),
                    style: AppTextStyles.body(onHero.withValues(alpha: 0.8), fontSize: AppTextStyles.size2xs)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            key: const Key('apply-suggested-price'),
            label: 'Use this price',
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}
