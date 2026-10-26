import 'package:flutter/foundation.dart';

import '../model/entities/user_entity.dart';
import '../model/exceptions/auth_exceptions.dart';
import '../model/rules/registration_rules.dart';
import '../model/use_cases/register_student_use_case.dart';

/// The fields of the sign-up form that can show an error.
enum RegisterField { name, email, major, password, confirm }

/// State and actions of the sign-up screen: what was typed, per-field errors, loading,
/// and creating the account. The screen only draws this and forwards input.
class RegisterViewModel extends ChangeNotifier {
  final RegisterStudentUseCase registerStudent;

  /// Called with the new user once the account exists; the app view-model then switches to Home.
  final void Function(UserEntity user) onSignedIn;

  RegisterViewModel({required this.registerStudent, required this.onSignedIn});

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

  String? errorFor(RegisterField field) => _errors[field];
  String? get faculty => _faculty;
  String get bannerError => _bannerError;
  bool get isLoading => _loading;
  bool get obscurePassword => _obscurePassword;

  /// Stores what was typed and clears that field's error.
  void update(RegisterField field, String value) {
    _values[field] = value;
    if (_errors.containsKey(field) || _bannerError.isNotEmpty) {
      _errors.remove(field);
      _bannerError = '';
      _notify();
    }
  }

  /// `null` means "no faculty".
  void setFaculty(String? faculty) {
    _faculty = faculty;
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
      // The account exists: sign the student in. The app switches to Home.
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
