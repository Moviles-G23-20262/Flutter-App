import '../../../app/network/api_client.dart';
import '../../entities/registration_data.dart';
import '../../entities/user_entity.dart';
import '../../exceptions/auth_exceptions.dart';
import '../auth_repository.dart';
import '../../data_sources/auth_remote_data_source.dart';
import '../../data_sources/session_storage.dart';
import '../../data_sources/local/response_cache.dart';
import '../../dto/auth_session_model.dart';
import '../../services/session_owner.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final SessionStorage storage;
  final BiometricCredentialStorage biometricStorage;
  final ApiClient apiClient;

  /// Where the signed-in profile is saved, so the app can open without a connection.
  /// Without it, an offline launch shows the login screen.
  final ResponseCache? profileCache;

  /// Told who is signed in, so per-user saved copies (wishlist, notifications) go to the right user.
  final SessionOwner? sessionOwner;

  /// The profile is saved for the device, not per user: there is one session at a time.
  static const String _profileOwner = 'device';
  static const String _profileKey = 'signed_in_profile';

  /// The session was opened from the saved profile and the server has not seen the token yet.
  bool _unverified = false;

  AuthRepositoryImpl({
    required this.remote,
    required this.storage,
    required this.biometricStorage,
    required this.apiClient,
    this.profileCache,
    this.sessionOwner,
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
      return await _verified(await remote.me());
    } on ApiException catch (e) {
      // Only a rejected token ends the session; a 5xx says nothing about it.
      if (e.statusCode == 401) {
        // The same token was enrolled for Quick Unlock, and it is dead too.
        await storage.clear();
        await _safely(biometricStorage.clear);
        await _forgetProfile();
      }
      apiClient.authToken = null;
      return null;
    } on NetworkException {
      // Offline at launch: open with the saved profile and keep the token, so requests work as
      // soon as the connection is back. Without a saved profile, show the login screen.
      final saved = await _savedProfile();
      if (saved == null) apiClient.authToken = null;
      _unverified = saved != null;
      if (saved != null) sessionOwner?.signedIn(saved.id);
      return saved;
    }
  }

  @override
  Future<UserEntity?> verifySession() async {
    if (!_unverified || apiClient.authToken == null) return null;
    try {
      return await _verified(await remote.me());
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // The client's onUnauthorized already signs the app out; drop what was kept for it.
        _unverified = false;
        sessionOwner?.signedOut();
        await storage.clear();
        await _safely(biometricStorage.clear);
        await _forgetProfile();
      }
      return null;
    } on NetworkException {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    // Only the active session ends. The biometric credential stays (see forgetBiometrics).
    apiClient.authToken = null;
    _unverified = false;
    sessionOwner?.signedOut();
    await storage.clear();
    // The profile stays only for the fingerprint account, so Quick Unlock also works offline.
    if (!await _profileIsFingerprintAccount()) await _forgetProfile();
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
      final user = await _verified(await remote.me());
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
      // The fingerprint was verified on the phone, so offline the saved profile of the same
      // account is enough to open the app; the token is checked when the connection returns.
      if (await _profileIsFingerprintAccount()) {
        await _safely(() => storage.saveToken(token!));
        _unverified = true;
        final saved = await _savedProfile();
        if (saved != null) sessionOwner?.signedIn(saved.id);
        return saved;
      }
      apiClient.authToken = null;
      throw const AuthNetworkException();
    }
  }

  @override
  Future<void> forgetBiometrics() async {
    await _safely(biometricStorage.clear);
    // Signed out and no fingerprint account any more: nothing on the phone needs the profile.
    if (apiClient.authToken == null) await _forgetProfile();
  }

  Future<UserEntity> _startSession(AuthSessionModel session) async {
    // The server accepted the credentials: the user is in, even if the token cannot be kept
    // on this device (secure storage unavailable). The session then just won't survive a restart.
    apiClient.authToken = session.accessToken;
    await _safely(() => storage.saveToken(session.accessToken));
    await _verified(session.user);
    // Signing in with credentials (re)enrolls this account for Quick Unlock.
    await _safely(() => biometricStorage.save(token: session.accessToken, email: session.user.email));
    return session.user;
  }

  /// The server just confirmed [user]: save the profile for the next offline launch.
  Future<UserEntity> _verified(UserEntity user) async {
    _unverified = false;
    sessionOwner?.signedIn(user.id);
    final cache = profileCache;
    if (cache != null) await _safely(() => cache.save(_profileOwner, _profileKey, userEntityToJson(user)));
    return user;
  }

  Future<UserEntity?> _savedProfile() async {
    try {
      final saved = await profileCache?.read(_profileOwner, _profileKey);
      return saved == null ? null : userEntityFromJson(saved.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _profileIsFingerprintAccount() async {
    final saved = await _savedProfile();
    final email = await enrolledEmail();
    return saved != null && email != null && saved.email.toLowerCase() == email.toLowerCase();
  }

  Future<void> _forgetProfile() async {
    final cache = profileCache;
    if (cache != null) await _safely(() => cache.remove(_profileOwner, _profileKey));
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
