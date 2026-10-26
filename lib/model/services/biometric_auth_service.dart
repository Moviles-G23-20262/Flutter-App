import 'package:local_auth/local_auth.dart';

import '../repositories/biometric_authenticator.dart';

/// Fingerprint / face unlock through local_auth (the native BiometricPrompt on Android).
class BiometricAuthService implements BiometricAuthenticator {
  static const String reason = 'Autentícate para ingresar a Viva Voce';

  final LocalAuthentication _auth;

  BiometricAuthService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> canCheckBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // PlatformException / LocalAuthException / missing plugin: no biometrics.
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      // Cancelled, locked out, no hardware, not enrolled...: the user is simply not verified.
      return false;
    }
  }
}
