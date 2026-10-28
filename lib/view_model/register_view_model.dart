import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/entities/registration_draft.dart';
import '../model/entities/user_entity.dart';
import '../model/exceptions/auth_exceptions.dart';
import '../model/rules/registration_rules.dart';
import '../model/use_cases/register_student_use_case.dart';
import '../model/use_cases/registration_draft_use_cases.dart';

/// The fields of the sign-up form that can show an error.
enum RegisterField { name, email, major, password, confirm }

/// State and actions of the sign-up screen: what was typed, per-field errors, loading,
/// and creating the account. The screen only draws this and forwards input.
///
/// Name, email, major and faculty are saved as a draft 0.4 s after the last change, so they
/// survive a closed app; the passwords never are. The draft is deleted once the account exists.
class RegisterViewModel extends ChangeNotifier {
  static const Duration draftDelay = Duration(milliseconds: 400);

  final RegisterStudentUseCase registerStudent;

  /// Called with the new user once the account exists; the app view-model then switches to Home.
  final void Function(UserEntity user) onSignedIn;

  /// The sign-up draft. Without them the form simply starts empty every time.
  final LoadRegistrationDraftUseCase? loadDraft;
  final SaveRegistrationDraftUseCase? saveDraft;
  final ClearRegistrationDraftUseCase? clearDraft;

  RegisterViewModel({
    required this.registerStudent,
    required this.onSignedIn,
    this.loadDraft,
    this.saveDraft,
    this.clearDraft,
  });

  /// The fields that go into the draft.
  static const Set<RegisterField> draftFields = {RegisterField.name, RegisterField.email, RegisterField.major};

  /// Shown as hints in the form.
  static const String institutionalDomain = RegistrationRules.institutionalDomain;
  static const int minPasswordLength = RegistrationRules.minPasswordLength;

  final Map<RegisterField, String> _values = {for (final f in RegisterField.values) f: ''};
  final Map<RegisterField, String> _errors = {};
  String? _faculty;
  String _bannerError = '';
  bool _loading = false;
  bool _obscurePassword = true;
  bool _disposed = false;
  Timer? _draftTimer;

  String? errorFor(RegisterField field) => _errors[field];

  /// What is stored for [field]; after [init] it can come from the draft.
  String valueOf(RegisterField field) => _values[field] ?? '';
  String? get faculty => _faculty;
  String get bannerError => _bannerError;
  bool get isLoading => _loading;
  bool get obscurePassword => _obscurePassword;

  /// Restores the saved draft. Returns `true` when there was one, so the screen fills its fields
  /// from [valueOf] and [faculty]. Call once when the screen opens.
  Future<bool> init() async {
    final draft = await loadDraft?.execute();
    if (draft == null || draft.isEmpty || _disposed) return false;
    _values[RegisterField.name] = draft.fullName;
    _values[RegisterField.email] = draft.email;
    _values[RegisterField.major] = draft.major;
    _faculty = draft.faculty;
    _notify();
    return true;
  }

  /// Stores what was typed and clears that field's error.
  void update(RegisterField field, String value) {
    _values[field] = value;
    if (draftFields.contains(field)) _scheduleDraftSave();
    if (_errors.containsKey(field) || _bannerError.isNotEmpty) {
      _errors.remove(field);
      _bannerError = '';
      _notify();
    }
  }

  /// `null` means "no faculty".
  void setFaculty(String? faculty) {
    _faculty = faculty;
    _scheduleDraftSave();
    _notify();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    _notify();
  }

  Future<void> submit() async {
    if (_loading) return;

    final errors = _validateAll();
    if (errors.isNotEmpty) {
      _errors
        ..clear()
        ..addAll(errors);
      _bannerError = '';
      _notify();
      return;
    }

    _loading = true;
    _bannerError = '';
    _notify();
    try {
      final user = await registerStudent.execute(
        fullName: _values[RegisterField.name]!,
        email: _values[RegisterField.email]!,
        password: _values[RegisterField.password]!,
        major: _values[RegisterField.major]!,
        faculty: _faculty,
      );
      // The account exists: the draft is no longer needed. Sign the student in; the app switches to Home.
      _draftTimer?.cancel();
      await clearDraft?.execute();
      onSignedIn(user);
    } on EmailAlreadyRegisteredException catch (e) {
      _errors[RegisterField.email] = e.message;
    } on AuthException catch (e) {
      _bannerError = e.message;
    } catch (_) {
      _bannerError = 'Unexpected error. Please try again.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Map<RegisterField, String> _validateAll() {
    final errors = <RegisterField, String>{};
    void check(RegisterField field, String? message) {
      if (message != null) errors[field] = message;
    }

    final v = _values;
    check(RegisterField.name, RegistrationRules.validateFullName(v[RegisterField.name]));
    check(RegisterField.email, RegistrationRules.validateEmail(v[RegisterField.email]));
    check(RegisterField.major, RegistrationRules.validateMajor(v[RegisterField.major]));
    check(RegisterField.password, RegistrationRules.validatePassword(v[RegisterField.password]));
    check(
      RegisterField.confirm,
      RegistrationRules.validateConfirmation(v[RegisterField.password]!, v[RegisterField.confirm]!),
    );
    return errors;
  }

  /// Debounce: every change restarts the timer, so only the last state is written.
  void _scheduleDraftSave() {
    if (saveDraft == null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDelay, _saveDraft);
  }

  Future<void> _saveDraft() async => saveDraft?.execute(RegistrationDraft(
        fullName: valueOf(RegisterField.name),
        email: valueOf(RegisterField.email),
        major: valueOf(RegisterField.major),
        faculty: _faculty,
      ));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A change still waiting for its timer is written now, so leaving the screen loses nothing.
  @override
  void dispose() {
    _disposed = true;
    if (_draftTimer?.isActive ?? false) {
      _draftTimer!.cancel();
      _saveDraft();
    }
    super.dispose();
  }
}
