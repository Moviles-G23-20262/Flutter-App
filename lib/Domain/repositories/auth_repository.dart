import '../Entities/registration_data.dart';
import '../Entities/user_entity.dart';

/// Owns the session: after a successful [register] or [login] the credentials
/// are kept so [restoreSession] can bring the user back on the next launch.
abstract class AuthRepository {
  /// Creates the account and signs the user in.
  Future<UserEntity> register(RegistrationData data);

  /// Throws [InvalidCredentialsException] when email or password are wrong.
  Future<UserEntity> login({required String email, required String password});

  /// The user of the stored session, or `null` if there is none or it expired.
  Future<UserEntity?> restoreSession();

  /// Ends the session (token, user). The fingerprint credential is kept, so Quick Unlock still
  /// works afterwards; see [forgetBiometrics].
  Future<void> logout();

  /// An account was enrolled for Quick Unlock on this device, and it survives [logout].
  Future<bool> hasEnrolledBiometricCredential();

  /// Email of the enrolled account, for display. Null when there is none.
  Future<String?> enrolledEmail();

  /// Signs back in with the stored biometric credential. Call it only after the sensor verified
  /// the user. Returns null when the server rejected the credential (it is then forgotten);
  /// throws [AuthNetworkException] / [AuthServerException] when it could not be checked (the
  /// credential is kept).
  Future<UserEntity?> restoreWithBiometricCredential();

  /// Removes the enrolled account, so the next sign-in starts from scratch.
  Future<void> forgetBiometrics();
}
