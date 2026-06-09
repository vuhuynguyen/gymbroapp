import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A `cookie_jar` [Storage] backed by the OS keystore, so the long-lived `gymbro_refresh`
/// cookie is persisted encrypted at rest — honoring AUTHENTICATION.md's "refresh token never in
/// plain storage" intent while still speaking the server's existing cookie protocol. The access
/// token, by contrast, lives only in memory (see TokenStore).
class SecureCookieStorage implements Storage {
  SecureCookieStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _prefix = 'cookie::';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: '$_prefix$key');
    }
  }
}
