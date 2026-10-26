import 'package:flutter/foundation.dart';

import '../model/entities/user_entity.dart';
import '../model/exceptions/auth_exceptions.dart';
import '../model/rules/login_rules.dart';
import '../model/use_cases/login_use_case.dart';
import '../model/use_cases/quick_unlock_use_cases.dart';

/// State and actions of the login screen: what was typed, validation, loading, errors,
/// and fingerprint Quick Unlock. The screen only draws this and forwards taps.
class LoginViewModel extends ChangeNotifier {
  final LoginUseCase login;

  /// Fingerprint Quick Unlock; without them it is just email and password.
  final CanQuickUnlockUseCase? canQuickUnlock;
  final QuickUnlockUseCase? quickUnlock;
  final ForgetBiometricsUseCase? forgetBiometrics;

  /// Called with the user once signed in; the app view-model then switches to Home.
  final void Function(UserEntity user) onSignedIn;

  LoginViewModel({
    required this.login,
    required this.onSignedIn,
    this.canQuickUnlock,
    this.quickUnlock,
    this.forgetBiometrics,
  });

  /// Characters the input fields refuse (emojis).
  static final RegExp blockedCharacters = LoginRules.emoji;

  String _email = '';
  String _password = '';
  String _errorMessage = '';
  bool _loading = false;
  bool _obscurePassword = true;
  bool _submitted = false; // the user already tried, so every problem is shown
  QuickUnlockOffer? _offer;
  bool _disposed = false;

  String get errorMessage => _errorMessage;
  bool get isLoading => _loading;
  bool get obscurePassword => _obscurePassword;

  /// Whether to show the fingerprint button.
  bool get canOfferQuickUnlock => _offer != null;

  /// The account Quick Unlock would sign in, when known.
  String? get quickUnlockEmail => _offer?.email;

  /// Email problems show as soon as something is typed; an empty field waits for the submit.
  String? get emailError {
    if (_email.isEmpty && !_submitted) return null;
    return LoginRules.validateEmail(_email);
  }

  /// The length rule waits for the submit (it would nag while typing); spaces-only shows at once.
  String? get passwordError {
    final error = LoginRules.validatePassword(_password);
    if (error == null) return null;
    if (_submitted) return error;
    return (_password.isNotEmpty && _password.trim().isEmpty) ? error : null;
  }

  /// Looks up whether a fingerprint account is enrolled. Call once when the screen opens.
  Future<void> init() async {
    final offer = await canQuickUnlock?.execute();
    _offer = offer;
    _notify();
  }

  void setEmail(String value) {
    _email = value;
    _errorMessage = '';
    _notify();
  }

  void setPassword(String value) {
    _password = value;
    _errorMessage = '';
    _notify();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    _notify();
  }

  Future<void> submit() async {
    if (_loading) return;
    _submitted = true;
    if (emailError != null || passwordError != null) {
      _errorMessage = '';
      _notify();
      return;
    }

    _loading = true;
    _errorMessage = '';
    _notify();
    try {
      final user = await login.execute(email: _email, password: _password);
      // The app switches to Home and this screen goes away, so loading stays on.
      onSignedIn(user);
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Unexpected error. Please try again.');
    }
  }

  /// Fingerprint, then the saved session: no email or password to retype.
  Future<void> unlockWithFingerprint() async {
    final unlock = quickUnlock;
    if (_loading || unlock == null) return;
    _loading = true;
    _errorMessage = '';
    _notify();

    final result = await unlock.execute();
    switch (result.outcome) {
      case QuickUnlockOutcome.unlocked:
        onSignedIn(result.user!);
      case QuickUnlockOutcome.notVerified:
        _fail('Fingerprint not verified. Try again or log in with your password.');
      case QuickUnlockOutcome.credentialRejected:
        _offer = null; // the repository forgot the rejected credential
        _fail('Your saved sign-in is no longer valid. Log in with your email and password.');
      case QuickUnlockOutcome.unreachable:
        _fail(result.message ?? 'Could not sign you in. Please try again.');
    }
  }

  /// "Sign in with a different account": forget the fingerprint account.
  Future<void> forgetFingerprintAccount() async {
    if (_loading) return;
    try {
      await forgetBiometrics?.execute();
    } catch (_) {}
    _offer = null;
    _errorMessage = '';
    _notify();
  }

  void _fail(String message) {
    _loading = false;
    _errorMessage = message;
    _notify();
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
