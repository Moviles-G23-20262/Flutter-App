import '../Entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Run once at startup: signs the user back in if a valid session is stored.
class RestoreSessionUseCase {
  final AuthRepository repository;

  RestoreSessionUseCase(this.repository);

  Future<UserEntity?> execute() => repository.restoreSession();
}
