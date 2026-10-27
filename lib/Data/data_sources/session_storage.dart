import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the access token survives app restarts.
abstract class SessionStorage {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<String?> readUserId();
  Future<void> saveUserId(String userId);
  Future<void> clear();
}

/// The credential that Quick Unlock uses. Kept apart from the session token on purpose: signing
/// out ends the session but leaves this in place, so the fingerprint can bring the account back.
/// Only [clear] (forgetting the fingerprint account) or a rejected token removes it.
abstract class BiometricCredentialStorage {
  Future<String?> readToken();
  Future<String?> readEmail();
  Future<void> save({required String token, required String email});
  Future<void> clear();
}

class SecureBiometricCredentialStorage implements BiometricCredentialStorage {
  static const _tokenKey = 'biometric_token';
  static const _emailKey = 'last_enrolled_email';

  final FlutterSecureStorage _storage;

  SecureBiometricCredentialStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> save({required String token, required String email}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: email);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }
}

class SecureSessionStorage implements SessionStorage {
  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage;

  SecureSessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  @override
  Future<void> saveUserId(String userId) => _storage.write(key: _userIdKey, value: userId);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
  }
}
