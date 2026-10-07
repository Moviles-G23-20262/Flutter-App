import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the access token survives app restarts.
abstract class SessionStorage {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  static const _tokenKey = 'access_token';

  final FlutterSecureStorage _storage;

  SecureSessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _tokenKey);
}
