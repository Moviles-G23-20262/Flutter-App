import '../repositories/auth_repository.dart';
import '../rules/registration_rules.dart';

/// Live check used by the register form: is this e-mail still free?
class CheckEmailAvailabilityUseCase {
  final AuthRepository repository;

  CheckEmailAvailabilityUseCase(this.repository);

  Future<bool> execute(String email) {
    return repository.isEmailAvailable(RegistrationRules.normalizeEmail(email));
  }
}
