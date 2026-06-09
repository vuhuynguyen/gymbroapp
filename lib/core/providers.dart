import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/token_refresher.dart';
import 'auth/token_store.dart';
import 'config/app_config.dart';
import 'network/auth_interceptor.dart';
import 'network/refresh_interceptor.dart';
import 'network/secure_cookie_storage.dart';
import 'storage/secure_store.dart';
import 'tenant/tenant_store.dart';

/// App-wide singleton wiring. Dependency graph is acyclic:
/// stores (leaf) → authDio → tokenRefresher → apiDio → repositories.

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final cookieJarProvider = Provider<CookieJar>(
  (ref) => PersistCookieJar(storage: SecureCookieStorage()),
);

/// In-memory access token; also a [Listenable] the router refreshes on.
final tokenStoreProvider = Provider<TokenStore>((ref) {
  final store = TokenStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Active `X-Tenant-Id`; persisted; a [Listenable] the router refreshes on.
final tenantStoreProvider = Provider<TenantStore>((ref) {
  final store = TenantStore(ref.read(secureStoreProvider));
  ref.onDispose(store.dispose);
  return store;
});

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      // Treat any <500 as a resolved response handled by callers/ApiException, except Dio still
      // throws for non-2xx by default — we keep the default and map DioException centrally.
      headers: {'Accept': 'application/json'},
    );

/// Interceptor-free Dio for the auth/cookie endpoints (login/register/refresh/logout/forgot/reset).
/// Carries the cookie manager so the rotating `gymbro_refresh` cookie is stored and replayed.
final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(CookieManager(ref.read(cookieJarProvider)));
  return dio;
});

final tokenRefresherProvider = Provider<TokenRefresher>(
  (ref) => TokenRefresher(ref.read(authDioProvider), ref.read(tokenStoreProvider)),
);

/// The data Dio used by every authenticated repository: cookie manager + auth headers + the
/// single-flight 401 refresh-and-replay.
final apiDioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(CookieManager(ref.read(cookieJarProvider)));
  dio.interceptors.add(AuthInterceptor(ref.read(tokenStoreProvider), ref.read(tenantStoreProvider)));
  dio.interceptors.add(RefreshInterceptor(refresher: ref.read(tokenRefresherProvider), dio: dio));
  return dio;
});
