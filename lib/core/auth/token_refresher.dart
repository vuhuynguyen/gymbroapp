import 'package:dio/dio.dart';
import 'token_store.dart';

/// Owns the single-flight silent refresh against the httpOnly `gymbro_refresh` cookie. Uses a
/// dedicated interceptor-free Dio (cookie manager only) so a 401 during refresh can never recurse.
///
/// The cookie is attached automatically by the shared CookieManager; the server rotates it
/// (reuse-detection + SecurityStamp machinery, see AUTHENTICATION.md) and returns a fresh
/// `{ token }`. We store the new access token in memory. On any failure we clear the session.
class TokenRefresher {
  TokenRefresher(this._authDio, this._tokenStore);

  final Dio _authDio;
  final TokenStore _tokenStore;
  Future<String?>? _inFlight;

  /// Returns the new access token, or null if refresh failed (session is gone).
  Future<String?> refresh() => _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<String?> _run() async {
    try {
      final res = await _authDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: const <String, dynamic>{},
      );
      final token = res.data?['token']?.toString();
      if (token == null || token.isEmpty) {
        _tokenStore.clear();
        return null;
      }
      _tokenStore.setToken(token);
      return token;
    } catch (_) {
      _tokenStore.clear();
      return null;
    }
  }
}
