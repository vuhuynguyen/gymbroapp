import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/token_refresher.dart';
import '../../core/auth/token_store.dart';
import '../../core/network/api_call.dart';
import '../../core/providers.dart';
import '../models/auth_models.dart';

/// All `/api/auth/*` calls. Anonymous/cookie endpoints use the interceptor-free [authDio]; the
/// authenticated ones (`me`, `change-password`, `logout-all`) use [apiDio] so they carry the Bearer
/// token and can refresh-and-replay.
class AuthRepository {
  AuthRepository({
    required Dio authDio,
    required Dio apiDio,
    required TokenStore tokenStore,
    required TokenRefresher refresher,
  })  : _authDio = authDio,
        _apiDio = apiDio,
        _tokenStore = tokenStore,
        _refresher = refresher;

  final Dio _authDio;
  final Dio _apiDio;
  final TokenStore _tokenStore;
  final TokenRefresher _refresher;

  Future<void> login(String email, String password) => apiCall(() async {
        final res = await _authDio.post<Map<String, dynamic>>(
          '/api/auth/login',
          data: {'email': email, 'password': password},
        );
        _tokenStore.setToken(AuthTokenResponse.fromJson(res.data!).token);
      });

  Future<void> register(String email, String password, String fullName) =>
      apiCall(() async {
        final res = await _authDio.post<Map<String, dynamic>>(
          '/api/auth/register',
          data: {'email': email, 'password': password, 'fullName': fullName},
        );
        _tokenStore.setToken(AuthTokenResponse.fromJson(res.data!).token);
      });

  /// Silent refresh against the secure-stored cookie. Returns true if a session was restored.
  Future<bool> restoreSession() async => (await _refresher.refresh()) != null;

  Future<Me> me() => apiCall(() async {
        final res = await _apiDio.get<Map<String, dynamic>>('/api/auth/me');
        return Me.fromJson(res.data!);
      });

  Future<void> forgotPassword(String email) => apiCall(() async {
        await _authDio
            .post<dynamic>('/api/auth/forgot-password', data: {'email': email});
      });

  Future<void> resetPassword(String email, String token, String newPassword) =>
      apiCall(() async {
        await _authDio.post<dynamic>(
          '/api/auth/reset-password',
          data: {'email': email, 'token': token, 'newPassword': newPassword},
        );
      });

  Future<void> changePassword(String currentPassword, String newPassword) =>
      apiCall(() async {
        await _apiDio.post<dynamic>(
          '/api/auth/change-password',
          data: {
            'currentPassword': currentPassword,
            'newPassword': newPassword
          },
        );
      });

  /// Logout this device (revokes the presented refresh token's family + clears the cookie).
  Future<void> logout() async {
    try {
      await _authDio.post<dynamic>('/api/auth/logout', data: const {});
    } catch (_) {
      // Local clear happens regardless — mirror the Portal.
    }
    _tokenStore.clear();
  }

  /// Logout everywhere (revokes all refresh tokens + rotates the SecurityStamp).
  Future<void> logoutAll() async {
    try {
      await _apiDio.post<dynamic>('/api/auth/logout-all', data: const {});
    } catch (_) {}
    _tokenStore.clear();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      authDio: ref.read(authDioProvider),
      apiDio: ref.read(apiDioProvider),
      tokenStore: ref.read(tokenStoreProvider),
      refresher: ref.read(tokenRefresherProvider),
    ));
