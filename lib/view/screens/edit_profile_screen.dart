import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../model/entities/uniandes_program.dart';
import '../../model/rules/profile_rules.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/edit_profile_view_model.dart';
import '../widgets/common_widgets.dart';
import '../widgets/offline_banner.dart';

/// Edit name, major and faculty. Only draws [EditProfileViewModel] and forwards input: the draft,
/// the connection and the request all live in the view-model.
class EditProfileScreen extends StatefulWidget {
  final AppViewModel appState;

  /// Builds this screen's view-model; called once, and the screen disposes it.
  final EditProfileViewModel Function() createViewModel;

  const EditProfileScreen({super.key, required this.appState, required this.createViewModel});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileViewModel _vm = widget.createViewModel();
  late final _nameCtrl = TextEditingController(text: _vm.fullName);
  late final _facultyCtrl = TextEditingController(text: _vm.faculty);
  final _majorFocus = FocusNode(debugLabel: 'major-picker');
  final _facultyFocus = FocusNode(debugLabel: 'faculty');
  final _nameEmoji = EmojiBlocker();

  late final _nameFormatters = <TextInputFormatter>[
    _nameEmoji,
    LengthLimitingTextInputFormatter(ProfileRules.maxNameLength),
  ];
  static final _facultyFormatters = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(ProfileRules.maxFacultyLength),
  ];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _vm.init();
    if (!mounted) return;
    // A restored draft replaces what the fields started with.
    _syncControllers();
  }

  void _syncControllers() {
    if (_nameCtrl.text != _vm.fullName) _nameCtrl.text = _vm.fullName;
    if (_facultyCtrl.text != _vm.faculty) _facultyCtrl.text = _vm.faculty;
  }

  @override
  void dispose() {
    _vm.dispose();
    _nameCtrl.dispose();
    _facultyCtrl.dispose();
    _majorFocus.dispose();
    _facultyFocus.dispose();
    _nameEmoji.dispose();
    super.dispose();
  }

  void _close() {
    if (_vm.isSaving) return;
    // Nothing is lost: the draft stays on the phone until it is saved or discarded.
    widget.appState.navigateTo(AppScreen.profile);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _vm.save();
    if (!ok || !mounted) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(key: Key('profile-saved-snackbar'), content: Text('Profile updated.')));
    widget.appState.navigateTo(AppScreen.profile);
  }

  Future<void> _discard() async {
    await _vm.discardChanges();
    if (mounted) _syncControllers();
  }

  Future<void> _pickMajor() async {
    FocusScope.of(context).unfocus();
    if (_vm.catalogFailed) {
      await _vm.retryCatalog();
      if (!mounted || _vm.catalogFailed) return;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showModalBottomSheet<UniandesProgram>(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ProgramPickerSheet(
        initial: _vm.programs,
        selected: _vm.selectedProgram,
        search: _vm.search,
      ),
    );
    if (picked == null || !mounted) return;
    await _vm.selectProgram(picked);
    if (!mounted) return;
    _syncControllers();
    _facultyFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildView(context),
    );
  }

  Widget _buildView(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txSecondary = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: surface,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back to profile. Unsaved changes stay on this phone.',
                      excludeSemantics: true,
                      child: AppIconButton(
                        key: const Key('edit-profile-back'),
                        icon: Icon(Icons.arrow_back_rounded, color: txSecondary, size: 18),
                        onTap: _close,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.edit_outlined, color: accentHi, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text('Edit Profile', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: border, height: 1),
              if (!_vm.isOnline)
                Semantics(
                  liveRegion: true,
                  child: const OfflineBanner(
                    key: Key('edit-profile-offline-banner'),
                    message: "You're offline. Keep editing: your changes are saved on this phone.",
                  ),
                ),
              Expanded(child: _vm.isLoading ? _loading(txSecondary) : _form(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading(Color txSecondary) {
    return Center(
      key: const Key('edit-profile-loading'),
      child: Semantics(
        liveRegion: true,
        label: 'Loading your profile',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 10),
            Text('Loading your profile…', style: AppTextStyles.body(txSecondary, fontSize: AppTextStyles.sizeXs)),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final errorColor = dark ? AppColors.darkError : AppColors.lightError;
    final warning = dark ? AppColors.darkWarning : AppColors.lightWarning;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_vm.restoredDraft) ...[
            AppCard(
              key: const Key('edit-profile-restored-draft'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: accentHi, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('We restored the changes you had not saved yet.',
                        style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeXs)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Email: shown, never sent.
          _Label('Email', color: txMuted),
          Semantics(
            label: 'Email, ${_vm.user.email}. It cannot be changed here.',
            excludeSemantics: true,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: txMuted, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_vm.user.email,
                        key: const Key('edit-profile-email'),
                        style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeSm)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Full name
          _Label('Full name', color: txMuted),
          Semantics(
            textField: true,
            label: 'Full name, 2 to ${ProfileRules.maxNameLength} characters: letters, spaces, periods and hyphens',
            child: AppTextField(
              key: const Key('edit-profile-name'),
              placeholder: 'Your full name',
              controller: _nameCtrl,
              enabled: !_vm.isSaving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              inputFormatters: _nameFormatters,
              errorText: _vm.fullNameError,
              onChanged: _vm.setFullName,
              onSubmitted: (_) => _majorFocus.requestFocus(),
            ),
          ),
          FieldFeedback(
            controller: _nameCtrl,
            max: ProfileRules.maxNameLength,
            counterShowFrom: 0.8,
            emojiBlocker: _nameEmoji,
            suppressHint: true,
          ),
          const SizedBox(height: 16),

          // Major (catalog picker)
          _Label('Major', color: txMuted),
          _MajorPicker(
            focusNode: _majorFocus,
            value: _vm.major,
            isLegacy: _vm.isLegacyMajor,
            catalogFailed: _vm.catalogFailed,
            loadingCatalog: _vm.isLoadingCatalog,
            enabled: !_vm.isSaving,
            error: _vm.majorError,
            onTap: _pickMajor,
          ),
          const SizedBox(height: 16),

          // Faculty (filled in from the major, editable)
          _Label('Faculty', color: txMuted),
          Semantics(
            textField: true,
            label: 'Faculty, optional, up to ${ProfileRules.maxFacultyLength} characters. '
                'Filled in when you choose your major',
            child: AppTextField(
              key: const Key('edit-profile-faculty'),
              placeholder: 'Filled in from your major',
              controller: _facultyCtrl,
              enabled: !_vm.isSaving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              inputFormatters: _facultyFormatters,
              errorText: _vm.facultyError,
              onChanged: _vm.setFaculty,
              onSubmitted: (_) {
                if (_vm.canSave) _save();
              },
            ),
          ),
          FieldFeedback(controller: _facultyCtrl, max: ProfileRules.maxFacultyLength, counterShowFrom: 0.8),
          const SizedBox(height: 22),

          Semantics(
            button: true,
            enabled: _vm.canSave,
            label: _vm.isSaving
                ? 'Saving your profile'
                : (_vm.canSave ? 'Save changes' : 'Save changes, disabled. ${_vm.saveDisabledReason ?? ''}'),
            excludeSemantics: true,
            child: PrimaryButton(
              key: const Key('edit-profile-save'),
              label: 'Save changes',
              fullWidth: true,
              isLoading: _vm.isSaving,
              onPressed: _vm.canSave ? _save : null,
            ),
          ),
          if (_vm.saveDisabledReason != null) ...[
            const SizedBox(height: 8),
            Text(
              _vm.saveDisabledReason!,
              key: const Key('edit-profile-save-reason'),
              style: AppTextStyles.body(_vm.isOnline ? txMuted : warning, fontSize: AppTextStyles.sizeXs),
            ),
          ],
          if (_vm.saveError != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: errorColor, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_vm.saveError!,
                        key: const Key('edit-profile-save-error'),
                        style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                  ),
                ],
              ),
            ),
          ],
          if (_vm.hasChanges || _vm.restoredDraft) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Discard changes and show your saved profile again',
              excludeSemantics: true,
              child: SecondaryButton(
                key: const Key('edit-profile-discard'),
                label: 'Discard changes',
                fullWidth: true,
                leadingIcon: Icon(Icons.undo_rounded, color: txMuted, size: 16),
                onPressed: _vm.isSaving ? null : _discard,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;

  const _Label(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExcludeSemantics(
        child: Text(text, style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// The major field: shows the choice and opens the searchable catalog.
class _MajorPicker extends StatelessWidget {
  final FocusNode focusNode;
  final String value;
  final bool isLegacy;
  final bool catalogFailed;
  final bool loadingCatalog;
  final bool enabled;
  final String? error;
  final VoidCallback onTap;

  const _MajorPicker({
    required this.focusNode,
    required this.value,
    required this.isLegacy,
    required this.catalogFailed,
    required this.loadingCatalog,
    required this.enabled,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final warning = dark ? AppColors.darkWarning : AppColors.lightWarning;
    final errorColor = dark ? AppColors.darkError : AppColors.lightError;
    final accent = dark ? AppColors.darkAccent : AppColors.lightAccent;

    final String hint;
    if (catalogFailed) {
      hint = '${EditProfileViewModel.catalogErrorMessage} Tap to try again.';
    } else if (isLegacy) {
      hint = 'This major is not in the Uniandes catalog. Tap to choose the matching program.';
    } else {
      hint = '';
    }

    final semanticsLabel = StringBuffer('Major, ${value.isEmpty ? 'not chosen' : value}. ');
    if (hint.isNotEmpty) semanticsLabel.write('$hint ');
    if (error != null) semanticsLabel.write('$error ');
    semanticsLabel.write('Opens the list of Uniandes programs.');

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
          if (enabled) onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Semantics(
            button: true,
            enabled: enabled,
            focused: focused,
            label: semanticsLabel.toString(),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  key: const Key('edit-profile-major'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: enabled ? onTap : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: error != null ? errorColor : (focused ? accent : border),
                        width: focused || error != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined, color: txMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            value.isEmpty ? 'Choose your major' : value,
                            key: const Key('edit-profile-major-value'),
                            style: AppTextStyles.body(value.isEmpty ? txMuted : txPrimary, fontSize: AppTextStyles.sizeSm),
                          ),
                        ),
                        if (loadingCatalog)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Icon(catalogFailed ? Icons.refresh_rounded : Icons.expand_more_rounded, color: txMuted, size: 20),
                      ],
                    ),
                  ),
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(hint,
                      key: const Key('edit-profile-major-hint'),
                      style: AppTextStyles.body(catalogFailed ? errorColor : warning, fontSize: AppTextStyles.sizeXs)),
                ],
                if (error != null && !isLegacy) ...[
                  const SizedBox(height: 4),
                  Text(error!,
                      key: const Key('edit-profile-major-error'),
                      style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Searchable list of the Uniandes programs; pops the one picked.
class _ProgramPickerSheet extends StatefulWidget {
  final List<UniandesProgram> initial;
  final UniandesProgram? selected;
  final Future<List<UniandesProgram>> Function(String query) search;

  const _ProgramPickerSheet({required this.initial, required this.selected, required this.search});

  @override
  State<_ProgramPickerSheet> createState() => _ProgramPickerSheetState();
}

class _ProgramPickerSheetState extends State<_ProgramPickerSheet> {
  late List<UniandesProgram> _results = widget.initial;
  final _queryCtrl = TextEditingController();
  int _query = 0;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _onQuery(String text) async {
    final query = ++_query;
    final results = await widget.search(text);
    // Only the answer to the latest text is shown.
    if (!mounted || query != _query) return;
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Choose your major',
                          style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close the list without choosing',
                    excludeSemantics: true,
                    child: IconButton(
                      key: const Key('program-picker-close'),
                      icon: Icon(Icons.close_rounded, color: txMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                textField: true,
                label: 'Search Uniandes programs by name or faculty',
                child: AppTextField(
                  key: const Key('program-picker-search'),
                  placeholder: 'Search a program or faculty',
                  controller: _queryCtrl,
                  prefixIcon: Icon(Icons.search_rounded, color: txMuted, size: 18),
                  textInputAction: TextInputAction.done,
                  onChanged: _onQuery,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Semantics(
                        liveRegion: true,
                        child: Text('No program matches your search.',
                            key: const Key('program-picker-empty'),
                            style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final program = _results[index];
                        final selected = program == widget.selected;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: '${program.name}, faculty of ${program.faculty}',
                          excludeSemantics: true,
                          child: ListTile(
                            key: Key('program-option-${program.name}'),
                            title: Text(program.name, style: AppTextStyles.body(txPrimary, fontSize: AppTextStyles.sizeSm)),
                            subtitle: Text(program.faculty, style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.size2xs)),
                            trailing: selected ? Icon(Icons.check_rounded, color: accentHi) : null,
                            onTap: () => Navigator.of(context).pop(program),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
