import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Widgets/common_widgets.dart';
import '../State Management/app_state.dart';
import '../../Domain/Entities/material_entity.dart';

// ─── New Listing Screen ───────────────────────────────────────────────────────

class NewListingScreen extends StatefulWidget {
  final AppState appState;

  const NewListingScreen({super.key, required this.appState});

  @override
  State<NewListingScreen> createState() => _NewListingScreenState();
}

class _NewListingScreenState extends State<NewListingScreen> {
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _courseCtrl      = TextEditingController();
  final _priceCtrl       = TextEditingController();

  MaterialConditionEnum _condition = MaterialConditionEnum.GOOD;
  MaterialCategoryEnum  _category  = MaterialCategoryEnum.BOOKS;
  int  _photoCount = 0;
  bool _aiReady    = false;
  bool _publishing = false;
  bool _published  = false;

  static const _aiSuggestion = ('LIKE_NEW', '22.00', '92%');

  bool get _canPublish =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      _priceCtrl.text.trim().isNotEmpty;

  void _simulatePhotoSelect() {
    setState(() {
      _photoCount = (_photoCount + 1).clamp(0, 3);
      if (_photoCount > 0) _aiReady = true;
    });
  }

  void _applyAiSuggestion() {
    setState(() {
      _condition = MaterialConditionEnum.LIKE_NEW;
      _priceCtrl.text = _aiSuggestion.$2;
    });
  }

  Future<void> _publishListing() async {
    if (!_canPublish || _publishing) return;
    setState(() => _publishing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() { _publishing = false; _published = true; });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Navigate to seller hub after publishing
    widget.appState.navigateTo(AppScreen.sellerHub);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _courseCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final surface     = brightness == Brightness.dark ? AppColors.darkSurface    : AppColors.lightSurface;
    final border      = brightness == Brightness.dark ? AppColors.darkBorder     : AppColors.lightBorder;
    final txPrimary   = brightness == Brightness.dark ? AppColors.darkTextPrimary: AppColors.lightTextPrimary;
    final txMuted     = brightness == Brightness.dark ? AppColors.darkTextMuted  : AppColors.lightTextMuted;
    final txSecondary = brightness == Brightness.dark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final accentHi    = brightness == Brightness.dark ? AppColors.darkAccentHi  : AppColors.lightAccentHi;
    final accentLo    = brightness == Brightness.dark ? AppColors.darkAccentLo  : AppColors.lightAccentLo;
    final accent      = brightness == Brightness.dark ? AppColors.darkAccent     : AppColors.lightAccent;
    final elevated    = brightness == Brightness.dark ? AppColors.darkElevated   : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final successColor= brightness == Brightness.dark ? AppColors.darkSuccess    : AppColors.lightSuccess;

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
                onTap: () => widget.appState.navigateTo(AppScreen.home),
              ),
              const SizedBox(width: 10),
              Icon(Icons.add_circle_outline_rounded, color: accentHi, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('List New Item', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd))),
            ],
          ),
        ),
        Divider(color: border, height: 1),

        // Success banner
        if (_published)
          Container(
            color: elevated,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: successColor, size: 15),
                const SizedBox(width: 8),
                Text('"${_titleCtrl.text}" is ready for campus buyers.',
                    style: AppTextStyles.body(successColor, fontSize: AppTextStyles.sizeXs)),
              ],
            ),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Photo Scan card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(brightness).copyWith(
                    border: Border.all(color: accentLo),
                    boxShadow: [BoxShadow(
                      color: brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent,
                      blurRadius: 22, offset: const Offset(0, 6),
                    )],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome_rounded, color: accentHi, size: 16),
                                    const SizedBox(width: 6),
                                    Text('AI Photo Scan', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Add clear photos and AI will estimate condition and suggest a fair price.',
                                    style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AppBadge('AI', highlighted: true),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Upload area
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: elevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accentHi.withValues(alpha: 0.5), style: BorderStyle.solid, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 54, height: 54,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [BoxShadow(color: brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent, blurRadius: 14, offset: const Offset(0, 4))],
                                  ),
                                  child: const Center(child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Upload item pictures', style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text('Front, back, labels, scratches – help AI judge condition.',
                                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _simulatePhotoSelect,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: accentLo),
                                      ),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        const Icon(Icons.photo_library_outlined, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Text('Gallery', style: AppTextStyles.body(Colors.white, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _simulatePhotoSelect,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: elevated,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderSubtle),
                                      ),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(Icons.camera_alt_outlined, color: txSecondary, size: 16),
                                        const SizedBox(width: 6),
                                        Text('Camera', style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Photo slots
                            Row(
                              children: List.generate(3, (i) => Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: i < _photoCount
                                        ? (brightness == Brightness.dark ? AppColors.darkTagBg : AppColors.lightTagBg)
                                        : surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderSubtle),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      i < _photoCount ? Icons.check_circle_rounded : Icons.image_outlined,
                                      color: i < _photoCount ? accentHi : txMuted,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              )),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // AI result
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: _aiReady
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('AI recommendation ready',
                                                style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w700)),
                                            Text('${_aiSuggestion.$3} confidence from $_photoCount photo${_photoCount != 1 ? 's' : ''}',
                                                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _applyAiSuggestion,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: elevated,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: borderSubtle),
                                          ),
                                          child: Text('Apply', style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.size2xs)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: _AiResultTile(label: 'Detected condition', value: 'Like New', brightness: brightness)),
                                      const SizedBox(width: 10),
                                      Expanded(child: _AiResultTile(label: 'Suggested price', value: '\$${_aiSuggestion.$2}', brightness: brightness)),
                                    ],
                                  ),
                                ],
                              )
                            : Text('Waiting for photos. Once added, AI will suggest condition and price before you publish.',
                                style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Listing details card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Title', txMuted: txMuted),
                      AppTextField(
                        placeholder: 'e.g. Organic Chemistry Textbook',
                        controller: _titleCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel('Description', txMuted: txMuted),
                      AppTextField(
                        placeholder: 'Condition notes, what is included, meetup details…',
                        controller: _descCtrl,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Course Code', txMuted: txMuted),
                                AppTextField(
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
                                _FieldLabel('Price (\$)', txMuted: txMuted),
                                AppTextField(
                                  placeholder: '0.00',
                                  controller: _priceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Condition selector
                Row(
                  children: [
                    Icon(Icons.label_outline_rounded, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Condition'),
                  ],
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: MaterialConditionEnum.values.map((c) => PillChip(
                      label: c.displayName,
                      active: _condition == c,
                      onTap: () => setState(() => _condition = c),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category selector
                Row(
                  children: [
                    Icon(Icons.category_outlined, color: txMuted, size: 16),
                    const SizedBox(width: 6),
                    SectionTitle('Category'),
                  ],
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: MaterialCategoryEnum.values.map((c) => PillChip(
                      label: c.displayName,
                      active: _category == c,
                      onTap: () => setState(() => _category = c),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Publish button
        Container(
          color: surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: AnimatedOpacity(
            opacity: _canPublish ? 1.0 : 0.65,
            duration: const Duration(milliseconds: 200),
            child: PrimaryButton(
              label: _publishing ? 'Publishing…' : 'Publish Listing',
              leadingIcon: _publishing ? null : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              onPressed: _canPublish && !_publishing ? _publishListing : null,
              fullWidth: true,
              isLoading: _publishing,
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color txMuted;

  const _FieldLabel(this.text, {required this.txMuted});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs, fontWeight: FontWeight.w500)),
  );
}

class _AiResultTile extends StatelessWidget {
  final String label;
  final String value;
  final Brightness brightness;

  const _AiResultTile({required this.label, required this.value, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final elevated  = brightness == Brightness.dark ? AppColors.darkElevated    : AppColors.lightElevated;
    final borderSubtle= brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txMuted   = brightness == Brightness.dark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final accentHi  = brightness == Brightness.dark ? AppColors.darkAccentHi   : AppColors.lightAccentHi;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
          const SizedBox(height: 3),
          Text(value, style: AppTextStyles.price(accentHi, fontSize: AppTextStyles.sizeSm)),
        ],
      ),
    );
  }
}

