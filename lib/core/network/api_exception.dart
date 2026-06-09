import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Typed failure surfaced to controllers/UI. The API's error envelope is inconsistent
/// (`{ code, message }` from AuthController vs a bare JSON string from `ToFailureResult`), so we
/// branch on the HTTP status and read whichever body shape we got. See memory
/// `gymbro-api-enum-wire-format`.
enum ApiErrorKind {
  network, // no/failed connection, timeout
  unauthorized, // 401 — token problem (interceptor handles refresh/replay first)
  forbidden, // 403 — permission / visibility / tenant denial
  notFound, // 404
  conflict, // 409 — e.g. second active session, skip-with-sets, duplicate assignment
  validation, // 400
  rateLimited, // 429
  server, // 5xx
  unknown,
}

class ApiException implements Exception {
  ApiException(this.kind, this.message, {this.statusCode, this.code});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;

  bool get isConflict => kind == ApiErrorKind.conflict;
  bool get isForbidden => kind == ApiErrorKind.forbidden;
  bool get isNotFound => kind == ApiErrorKind.notFound;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    final status = res?.statusCode ?? 0;
    final isTimeout = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;

    // No response, an explicit connection error, or a status-0 / sub-100 response (a CORS-blocked or
    // opaque response on web, or a refused/aborted socket) all mean we never got a real reply from
    // the API — surface a clear connectivity error instead of the generic "Request failed."
    if (res == null ||
        isTimeout ||
        e.type == DioExceptionType.connectionError ||
        status < 100) {
      return ApiException(ApiErrorKind.network, _unreachableMessage(isTimeout));
    }

    final (message, code) = _readBody(res.data);

    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      400 || 422 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };

    return ApiException(kind, message ?? _defaultMessage(kind),
        statusCode: status, code: code);
  }

  /// Connectivity-failure copy. In debug we name the host we tried, so a developer can instantly tell
  /// "API not running / wrong environment" apart from a real outage (e.g. after switching env files).
  static String _unreachableMessage(bool isTimeout) {
    if (isTimeout) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (kDebugMode) {
      return "Couldn't reach the API at ${AppConfig.apiBaseUrl} — "
          'is the backend running and reachable?';
    }
    return 'Cannot reach GymBro. Check your connection and try again.';
  }

  static (String?, String?) _readBody(Object? data) {
    if (data is String && data.trim().isNotEmpty) return (data, null);
    if (data is Map) {
      final msg = data['message'] ?? data['detail'] ?? data['title'];
      final code = data['code'];
      return (msg?.toString(), code?.toString());
    }
    return (null, null);
  }

  static String _defaultMessage(ApiErrorKind kind) => switch (kind) {
        ApiErrorKind.unauthorized =>
          'Your session has expired. Please sign in again.',
        ApiErrorKind.forbidden => 'You do not have access to this.',
        ApiErrorKind.notFound => 'Not found.',
        ApiErrorKind.conflict =>
          'That action conflicts with the current state.',
        ApiErrorKind.validation => 'The request was invalid.',
        ApiErrorKind.rateLimited =>
          'Too many attempts. Please wait a moment and try again.',
        ApiErrorKind.server =>
          'Something went wrong on the server. Please try again.',
        ApiErrorKind.network => 'Network error.',
        ApiErrorKind.unknown => 'Request failed.',
      };
}
