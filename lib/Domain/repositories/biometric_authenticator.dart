/// The phone's biometric sensor (fingerprint, face).
abstract class BiometricAuthenticator {
  /// The device has biometric hardware and at least one enrolled fingerprint or face.
  /// Never throws: any failure means "not available".
  Future<bool> canCheckBiometrics();

  /// Shows the system prompt. True only when the user was verified. Never throws: a
  /// cancelled prompt, too many attempts or a missing sensor all give false.
  Future<bool> authenticate();
}
