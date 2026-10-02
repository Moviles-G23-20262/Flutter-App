import '../../core/network/api_client.dart';
import '../../Domain/Entities/registration_data.dart';
import '../../Domain/Entities/user_entity.dart';
import '../Models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login({required String email, required String password});
  Future<AuthSessionModel> register(RegistrationData data);

  /// Needs [ApiClient.authToken] to be set.
  Future<UserEntity> me();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AuthSessionModel> login({required String email, required String password}) async {
    final response = await apiClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSessionModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AuthSessionModel> register(RegistrationData data) async {
    final response = await apiClient.post(
      '/auth/register',
      body: {
        'email': data.email,
        'password': data.password,
        'fullName': data.fullName,
        'major': data.major,
        if (data.faculty != null) 'faculty': data.faculty,
      },
    );
    return AuthSessionModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<UserEntity> me() async {
    final response = await apiClient.get('/auth/me');
    return userEntityFromJson(response as Map<String, dynamic>);
  }
}
