import 'package:dio/dio.dart';
import '../auth/token_refresher.dart';

/// Single-flight 401 refresh-and-replay — a direct port of the Portal's `error-interceptor`.
///
/// On a 401 from a non-auth call: silently refresh once (deduped by [TokenRefresher]), then replay
/// the original request a single time with the fresh access token. If refresh fails, the token store
/// is cleared and the original error propagates — the router redirect bounces to login.
///
/// Uses [QueuedInterceptor] so concurrent 401s are processed sequentially; combined with the
/// refresher's single-flight, that means exactly one `/api/auth/refresh` per expiry.
class RefreshInterceptor extends QueuedInterceptor {
  RefreshInterceptor({required this.refresher, required this.dio});

  final TokenRefresher refresher;
  final Dio dio;

  // Auth endpoints manage their own 401s — never recurse into a refresh for these.
  static const _authPaths = [
    '/api/auth/refresh',
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/logout',
  ];

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final isAuthCall = _authPaths.any(req.path.contains);
    final alreadyRetried = req.extra['__retried'] == true;

    if (err.response?.statusCode != 401 || isAuthCall || alreadyRetried) {
      return handler.next(err);
    }

    final newToken = await refresher.refresh();
    if (newToken == null) {
      // Session is truly gone; token store cleared → auth redirect handles logout.
      return handler.next(err);
    }

    try {
      final clone = await dio.request<dynamic>(
        req.path,
        data: req.data,
        queryParameters: req.queryParameters,
        cancelToken: req.cancelToken,
        options: Options(
          method: req.method,
          headers: Map<String, dynamic>.of(req.headers)..['Authorization'] = 'Bearer $newToken',
          responseType: req.responseType,
          contentType: req.contentType,
          extra: {...req.extra, '__retried': true},
          validateStatus: req.validateStatus,
        ),
      );
      return handler.resolve(clone);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
