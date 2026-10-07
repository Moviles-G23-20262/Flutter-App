import '../Entities/user_entity.dart';
import '../exceptions/auth_exceptions.dart';
import '../repositories/auth_repository.dart';
import '../rules/registration_rules.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<UserEntity> execute({required String email, required String password}) async {
    final cleanEmail = RegistrationRules.normalizeEmail(email);
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const InvalidCredentialsException();
    }
    // The institutional-domain rule is for sign-up only: accounts created
    // before it existed must still be able to log in.
    return repository.login(email: cleanEmail, password: password);
  }
}
