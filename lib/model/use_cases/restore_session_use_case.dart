import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Run once at startup: signs the user back in if a valid session is stored.
class RestoreSessionUseCase {
  final AuthRepository repository;

  RestoreSessionUseCase(this.repository);

  Future<UserEntity?> execute() => repository.restoreSession();
}

/// For a session opened offline from the saved profile: checks the token once the server can be
/// reached. Returns the fresh profile, or `null` when there was nothing to check.
class VerifySessionUseCase {
  final AuthRepository repository;

  VerifySessionUseCase(this.repository);

  Future<UserEntity?> execute() => repository.verifySession();
}
