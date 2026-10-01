import 'dart:async';

import 'package:flutter/material.dart';

import '../../Domain/errors/auth_exceptions.dart';
import '../../Domain/rules/registration_rules.dart';
import '../../Domain/use_cases/check_email_availability_use_case.dart';
import '../../Domain/use_cases/register_student_use_case.dart';
import '../../theme/app_theme.dart';
import '../State Management/app_state.dart';
import '../Widgets/common_widgets.dart';

enum _Field { name, email, major, password, confirm }

enum _EmailStatus { idle, checking, available, taken }

const List<String> _faculties = [
  'Faculty of Administration',
  'Faculty of Architecture and Design',
  'Faculty of Arts and Humanities',
  'Faculty of Economics',
  'Faculty of Education',
  'Faculty of Engineering',
  'Faculty of Law',
  'Faculty of Medicine',
  'Faculty of Sciences',
  'Faculty of Social Sciences',
];

const String _noFaculty = '';

class RegisterScreen extends StatefulWidget {
  final AppState appState;
  final RegisterStudentUseCase registerStudent;
  final CheckEmailAvailabilityUseCase checkEmailAvailability;

  const RegisterScreen({
    super.key,
    required this.appState,
    required this.registerStudent,
    required this.checkEmailAvailability,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _facultyCtrl = TextEditingController();
  final _majorCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final Map<_Field, String> _errors = {};
  String? _faculty;
  String _bannerError = '';
  bool _loading = false;
  bool _obscure = true;

  _EmailStatus _emailStatus = _EmailStatus.idle;
  Timer? _emailDebounce;
  int _emailCheckId = 0;

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _facultyCtrl.dispose();
    _majorCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }


  void _clearError(_Field field) {
    if (_errors.containsKey(field) || _bannerError.isNotEmpty) {
      setState(() {
        _errors.remove(field);
        _bannerError = '';
      });
    }
  }

  void _onEmailChanged(String raw) {
    _emailDebounce?.cancel();
    final checkId = ++_emailCheckId;
    setState(() {
      _errors.remove(_Field.email);
      _bannerError = '';
      _emailStatus = _EmailStatus.idle;
    });

    final email = RegistrationRules.normalizeEmail(raw);
    if (RegistrationRules.validateEmail(email) != null) return;

    _emailDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _checkEmail(email, checkId),
    );
  }

  Future<void> _checkEmail(String email, int checkId) async {
    if (!mounted) return;
    setState(() => _emailStatus = _EmailStatus.checking);
    try {
      final available = await widget.checkEmailAvailability.execute(email);
      if (!mounted || checkId != _emailCheckId) return;
      setState(() {
        _emailStatus = available ? _EmailStatus.available : _EmailStatus.taken;
        if (!available) {
          _errors[_Field.email] = 'An account with this email already exists.';
        }
      });
    } catch (_) {
      // Best effort: if the check fails (offline, server down) the server still
      // rejects duplicates when the form is submitted.
      if (!mounted || checkId != _emailCheckId) return;
      setState(() => _emailStatus = _EmailStatus.idle);
    }
  }

  Map<_Field, String> _validateAll() {
    final errors = <_Field, String>{};
    void check(_Field field, String? message) {
      if (message != null) errors[field] = message;
    }

    check(_Field.name, RegistrationRules.validateFullName(_nameCtrl.text));
    check(_Field.email, RegistrationRules.validateEmail(_emailCtrl.text));
    check(_Field.major, RegistrationRules.validateMajor(_majorCtrl.text));
    check(_Field.password, RegistrationRules.validatePassword(_passwordCtrl.text));
    check(
      _Field.confirm,
      RegistrationRules.validateConfirmation(_passwordCtrl.text, _confirmCtrl.text),
    );
    if (!errors.containsKey(_Field.email) && _emailStatus == _EmailStatus.taken) {
      errors[_Field.email] = 'An account with this email already exists.';
    }
    return errors;
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final errors = _validateAll();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _bannerError = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _bannerError = '';
    });

    try {
      final user = await widget.registerStudent.execute(
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        major: _majorCtrl.text,
        faculty: _faculty,
      );
      if (!mounted) return;
      // The account exists: sign the student in. AppState switches to Home.
      widget.appState.login(user);
    } on EmailAlreadyRegisteredException catch (e) {
      if (!mounted) return;
      setState(() {
        _emailStatus = _EmailStatus.taken;
        _errors[_Field.email] = e.message;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _bannerError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bannerError = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFaculty() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FacultySheet(selected: _faculty),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _faculty = selected == _noFaculty ? null : selected;
      _facultyCtrl.text = _faculty ?? '';
    });
  }

  void _goToLogin() {
    if (_loading) return;
    widget.appState.navigateTo(AppScreen.login);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentHi = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToLogin();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back to log in',
                    onPressed: _loading ? null : _goToLogin,
                    icon: Icon(Icons.arrow_back_rounded, color: txMuted),
                  ),
                ),
                const SizedBox(height: 4),
                const CampusSwapLogo(size: 56),
                const SizedBox(height: 14),
                Text(
                  'Create your account',
                  style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeLg),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Only verified Uniandes students can join.',
                  style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                AppCard(child: _buildForm()),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _goToLogin,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs),
                          children: [
                            TextSpan(
                              text: 'Log in',
                              style: AppTextStyles.body(
                                accentHi,
                                fontSize: AppTextStyles.sizeXs,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledField(
          label: 'Full name',
          child: AppTextField(
            placeholder: 'Ana Gomez',
            controller: _nameCtrl,
            enabled: !_loading,
            textCapitalization: TextCapitalization.words,
            errorText: _errors[_Field.name],
            onChanged: (_) => _clearError(_Field.name),
          ),
        ),
        _LabeledField(
          label: 'Institutional email',
          child: AppTextField(
            placeholder: 'name${RegistrationRules.institutionalDomain}',
            controller: _emailCtrl,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            errorText: _errors[_Field.email],
            onChanged: _onEmailChanged,
            suffixIcon: _emailSuffix(),
          ),
        ),
        _LabeledField(
          label: 'Faculty (optional)',
          child: AppTextField(
            placeholder: 'Select your faculty',
            controller: _facultyCtrl,
            readOnly: true,
            enabled: !_loading,
            onTap: _pickFaculty,
            suffixIcon: const Icon(Icons.expand_more_rounded, size: 22),
          ),
        ),
        _LabeledField(
          label: 'Major',
          child: AppTextField(
            placeholder: 'Computer Science',
            controller: _majorCtrl,
            enabled: !_loading,
            textCapitalization: TextCapitalization.words,
            errorText: _errors[_Field.major],
            onChanged: (_) => _clearError(_Field.major),
          ),
        ),
        _LabeledField(
          label: 'Password',
          child: AppTextField(
            placeholder: 'Create a password',
            controller: _passwordCtrl,
            enabled: !_loading,
            obscureText: _obscure,
            errorText: _errors[_Field.password],
            onChanged: (_) => _clearError(_Field.password),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
              ),
            ),
          ),
          footer: _PasswordHint(length: _passwordCtrl.text.length),
        ),
        _LabeledField(
          label: 'Confirm password',
          child: AppTextField(
            placeholder: 'Repeat your password',
            controller: _confirmCtrl,
            enabled: !_loading,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            errorText: _errors[_Field.confirm],
            onChanged: (_) => _clearError(_Field.confirm),
          ),
        ),
        if (_bannerError.isNotEmpty) ...[
          _ErrorBanner(message: _bannerError),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 4),
        PrimaryButton(
          label: _loading ? 'Creating account…' : 'Create account',
          onPressed: _loading ? null : _submit,
          leadingIcon: _loading
              ? null
              : const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
          fullWidth: true,
          isLoading: _loading,
        ),
      ],
    );
  }

  Widget? _emailSuffix() {
    switch (_emailStatus) {
      case _EmailStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _EmailStatus.available:
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: dark ? AppColors.darkSuccess : AppColors.lightSuccess,
        );
      case _EmailStatus.idle:
      case _EmailStatus.taken:
        return null;
    }
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? footer;

  const _LabeledField({required this.label, required this.child, this.footer});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.body(txMuted, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          child,
          if (footer != null) ...[
            const SizedBox(height: 6),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _PasswordHint extends StatelessWidget {
  final int length;

  const _PasswordHint({required this.length});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ok = length >= RegistrationRules.minPasswordLength;
    final color = ok
        ? (dark ? AppColors.darkSuccess : AppColors.lightSuccess)
        : (dark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    return Row(
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          'At least ${RegistrationRules.minPasswordLength} characters',
          style: AppTextStyles.body(color, fontSize: AppTextStyles.sizeXs),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final elevated = dark ? AppColors.darkElevated : AppColors.lightElevated;
    final borderSubtle = dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle;
    final errorColor = dark ? AppColors.darkError : AppColors.lightError;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderSubtle),
        ),
        child: Text(message, style: AppTextStyles.body(errorColor, fontSize: AppTextStyles.sizeXs)),
      ),
    );
  }
}

/// Bottom sheet with the list of faculties.
class _FacultySheet extends StatelessWidget {
  final String? selected;

  const _FacultySheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final txPrimary = dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final txMuted = dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accent = dark ? AppColors.darkAccentHi : AppColors.lightAccentHi;

    Widget option(String value, String label, {bool muted = false}) {
      final isSelected = value == selected;
      return ListTile(
        minVerticalPadding: 14,
        title: Text(
          label,
          style: AppTextStyles.body(
            muted ? txMuted : (isSelected ? accent : txPrimary),
            fontSize: AppTextStyles.sizeSm,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check_rounded, color: accent) : null,
        onTap: () => Navigator.of(context).pop(value),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: txMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text('Select your faculty', style: AppTextStyles.heading(txPrimary, fontSize: AppTextStyles.sizeMd)),
          const SizedBox(height: 6),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final faculty in _faculties) option(faculty, faculty),
                option(_noFaculty, 'Prefer not to say', muted: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
