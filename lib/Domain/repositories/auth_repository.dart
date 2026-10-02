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

  Future<void> logout();
}
