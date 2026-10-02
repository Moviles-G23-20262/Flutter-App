import '../../core/network/api_client.dart';
import '../../Domain/Entities/registration_data.dart';
import '../../Domain/Entities/user_entity.dart';
import '../../Domain/exceptions/auth_exceptions.dart';
import '../../Domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../data_sources/session_storage.dart';
import '../Models/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final SessionStorage storage;
  final ApiClient apiClient;

  AuthRepositoryImpl({
    required this.remote,
    required this.storage,
    required this.apiClient,
  });

  @override
  Future<UserEntity> register(RegistrationData data) async {
    try {
      return await _startSession(await remote.register(data));
    } on ApiException catch (e) {
      throw _mapApiError(e);
    } on NetworkException {
      throw const AuthNetworkException();
    }
  }

  @override
  Future<UserEntity> login({required String email, required String password}) async {
    try {
      return await _startSession(await remote.login(email: email, password: password));
    } on ApiException catch (e) {
      throw _mapApiError(e);
    } on NetworkException {
      throw const AuthNetworkException();
    }
  }

  @override
  Future<UserEntity?> restoreSession() async {
    final token = await storage.readToken();
    if (token == null) return null;

    apiClient.authToken = token;
    try {
      return await remote.me();
    } on ApiException catch (e) {
      // Only a rejected token ends the session; a 5xx says nothing about it.
      if (e.statusCode == 401) await storage.clear();
      apiClient.authToken = null;
      return null;
    } on NetworkException {
      // Offline at launch: keep the token for next time, show the login screen.
      apiClient.authToken = null;
      return null;
    }
  }

  @override
  Future<void> logout() async {
    apiClient.authToken = null;
    await storage.clear();
  }

  Future<UserEntity> _startSession(AuthSessionModel session) async {
    await storage.saveToken(session.accessToken);
    apiClient.authToken = session.accessToken;
    return session.user;
  }

  AuthException _mapApiError(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return InvalidRegistrationException(e.message);
      case 401:
        return const InvalidCredentialsException();
      case 409:
        return const EmailAlreadyRegisteredException();
      default:
        return const AuthServerException();
    }
  }
}
