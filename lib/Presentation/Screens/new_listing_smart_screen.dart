import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/use_cases/price_estimator_use_case.dart';

// ─── Smart New Listing Screen (camera + fair price estimate) ─────────────────

class NewListingSmartScreen extends StatefulWidget {
  final AppState appState;

  const NewListingSmartScreen({super.key, required this.appState});

  @override
  State<NewListingSmartScreen> createState() => _NewListingSmartScreenState();
}

class _NewListingSmartScreenState extends State<NewListingSmartScreen> {
  final _picker = ImagePicker();
  final _estimator = const PriceEstimatorUseCase();

  Uint8List? _imageBytes;
  MaterialCategoryEnum _category = MaterialCategoryEnum.BOOKS;
  MaterialConditionEnum _condition = MaterialConditionEnum.GOOD;
  PriceEstimate? _estimate;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access the camera or gallery. Check app permissions.')),
      );
    }
  }

  void _suggestPrice() {
    setState(() {
      _estimate = _estimator.execute(category: _category, condition: _condition);
    });
  }

  void _resetEstimate(VoidCallback change) {
    setState(() {
      change();
      _estimate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                          active: _category == c,
                          onTap: () => _resetEstimate(() => _category = c),
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
                          active: _condition == c,
                          onTap: () => _resetEstimate(() => _condition = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: 'Suggest Fair Price',
                    fullWidth: true,
                    leadingIcon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    onPressed: _suggestPrice,
                  ),

                  if (_estimate != null) ...[
                    const SizedBox(height: 16),
                    _EstimateCard(estimate: _estimate!),
                  ],
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
  final PriceEstimate estimate;

  const _EstimateCard({required this.estimate});

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
          Text('₱${estimate.suggestedPrice.toStringAsFixed(2)}',
              style: AppTextStyles.mono(onHero, fontSize: AppTextStyles.sizeXl, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Historical range (p25–p75): ₱${estimate.p25.toStringAsFixed(2)} – ₱${estimate.p75.toStringAsFixed(2)}',
            style: AppTextStyles.mono(onHero.withValues(alpha: 0.85), fontSize: AppTextStyles.sizeXs),
          ),
          const SizedBox(height: 8),
          Text('Simulated estimate based on category and condition.',
              style: AppTextStyles.body(onHero.withValues(alpha: 0.6), fontSize: AppTextStyles.size2xs)),
        ],
      ),
    );
  }
}
