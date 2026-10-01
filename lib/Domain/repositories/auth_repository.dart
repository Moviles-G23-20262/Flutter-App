import '../Entities/registration_data.dart';
import '../Entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> register(RegistrationData data);

  Future<bool> isEmailAvailable(String email);
}
