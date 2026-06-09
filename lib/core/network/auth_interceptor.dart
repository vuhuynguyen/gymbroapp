import 'package:dio/dio.dart';
import '../auth/token_store.dart';
import '../config/app_config.dart';
import '../tenant/tenant_store.dart';

/// Attaches `Authorization: Bearer <access>`, the membership-validated `X-Tenant-Id`, and
/// (optionally) `X-Api-Version` to every request on the data Dio. Direct port of the Portal's
/// `authInterceptor`. The server re-validates tenant membership — the client never assumes it.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStore, this._tenantStore);

  final TokenStore _tokenStore;
  final TenantStore _tenantStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStore.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final tenantId = _tenantStore.activeTenantId;
    if (tenantId != null) {
      options.headers['X-Tenant-Id'] = tenantId;
    }
    if (AppConfig.apiVersion.isNotEmpty) {
      options.headers['X-Api-Version'] = AppConfig.apiVersion;
    }
    handler.next(options);
  }
}
