import '../../../app/network/api_client.dart';
import '../../entities/registration_data.dart';
import '../../entities/user_entity.dart';
import '../../exceptions/auth_exceptions.dart';
import '../auth_repository.dart';
import '../../data_sources/auth_remote_data_source.dart';
import '../../data_sources/session_storage.dart';
import '../../dto/auth_session_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final SessionStorage storage;
  final BiometricCredentialStorage biometricStorage;
  final ApiClient apiClient;

  AuthRepositoryImpl({
    required this.remote,
    required this.storage,
    required this.biometricStorage,
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
      if (e.statusCode == 401) {
        // The same token was enrolled for Quick Unlock, and it is dead too.
        await storage.clear();
        await _safely(biometricStorage.clear);
      }
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
    // Only the active session ends. The biometric credential stays (see forgetBiometrics).
    apiClient.authToken = null;
    await storage.clear();
  }

  @override
  Future<bool> hasEnrolledBiometricCredential() async {
    try {
      return await biometricStorage.readToken() != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> enrolledEmail() async {
    try {
      return await biometricStorage.readEmail();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserEntity?> restoreWithBiometricCredential() async {
    final String? token;
    try {
      token = await biometricStorage.readToken();
    } catch (_) {
      return null;
    }
    if (token == null) return null;

    apiClient.authToken = token;
    try {
      final user = await remote.me();
      // The session is back: keep it for the next launch like a normal sign-in does.
      await _safely(() => storage.saveToken(token!));
      return user;
    } on ApiException catch (e) {
      apiClient.authToken = null;
      if (e.statusCode == 401) {
        await _safely(biometricStorage.clear);
        return null;
      }
      throw const AuthServerException();
    } on NetworkException {
      apiClient.authToken = null;
      throw const AuthNetworkException();
    }
  }

  @override
  Future<void> forgetBiometrics() => _safely(biometricStorage.clear);

  Future<UserEntity> _startSession(AuthSessionModel session) async {
    // The server accepted the credentials: the user is in, even if the token cannot be kept
    // on this device (secure storage unavailable). The session then just won't survive a restart.
    apiClient.authToken = session.accessToken;
    await _safely(() => storage.saveToken(session.accessToken));
    // Signing in with credentials (re)enrolls this account for Quick Unlock.
    await _safely(() => biometricStorage.save(token: session.accessToken, email: session.user.email));
    return session.user;
  }

  /// Secure storage can fail on some devices; that must never break signing in or out.
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
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
