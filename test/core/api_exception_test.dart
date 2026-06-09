import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/core/network/api_exception.dart';

/// Regression coverage for the connectivity-vs-"Request failed" mapping. A status-0 / opaque response
/// (web CORS block, or a refused socket against a local dev API) used to fall through to
/// [ApiErrorKind.unknown] → "Request failed.", which hides the real cause. It must read as a network
/// error instead, while genuine HTTP statuses keep their precise kind + server message.
void main() {
  RequestOptions opts() => RequestOptions(path: '/api/auth/login');

  group('ApiException.fromDio classifies unreachable-server failures as network', () {
    test('status-0 / opaque response → network (not unknown)', () {
      final ex = ApiException.fromDio(DioException(
        requestOptions: opts(),
        response: Response(requestOptions: opts(), statusCode: 0),
        type: DioExceptionType.badResponse,
      ));
      expect(ex.kind, ApiErrorKind.network);
      expect(ex.message, isNot('Request failed.'));
    });

    test('connectionError with no response → network', () {
      final ex = ApiException.fromDio(DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionError,
      ));
      expect(ex.kind, ApiErrorKind.network);
    });

    test('connection timeout → network with a timeout message', () {
      final ex = ApiException.fromDio(DioException(
        requestOptions: opts(),
        type: DioExceptionType.connectionTimeout,
      ));
      expect(ex.kind, ApiErrorKind.network);
      expect(ex.message.toLowerCase(), contains('timed out'));
    });
  });

  group('ApiException.fromDio preserves real HTTP failures', () {
    test('401 → unauthorized, surfacing the server message', () {
      final ex = ApiException.fromDio(DioException(
        requestOptions: opts(),
        response: Response(
          requestOptions: opts(),
          statusCode: 401,
          data: {'message': 'Invalid email or password.'},
        ),
        type: DioExceptionType.badResponse,
      ));
      expect(ex.kind, ApiErrorKind.unauthorized);
      expect(ex.message, 'Invalid email or password.');
    });

    test('409 → conflict', () {
      final ex = ApiException.fromDio(DioException(
        requestOptions: opts(),
        response: Response(requestOptions: opts(), statusCode: 409),
        type: DioExceptionType.badResponse,
      ));
      expect(ex.kind, ApiErrorKind.conflict);
    });
  });
}
