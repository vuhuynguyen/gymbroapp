import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/core/network/api_exception.dart';
import 'package:gymbroapp/data/repositories/session_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// Backend-compat shim: API builds that predate `MeController` 404 the entire `/api/me/*` surface.
/// `myHistory`/`myDetail` must fall back to the tenant-scoped `/api/sessions` endpoints on a 404 so
/// the app keeps working during the API rollout — but must NOT swallow other failures.
void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  late _MockDio dio;
  late SessionRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = SessionRepository(dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> data, String path) =>
      Response(data: data, statusCode: 200, requestOptions: RequestOptions(path: path));

  DioException httpStatus(int code, String path) => DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(statusCode: code, requestOptions: RequestOptions(path: path)),
      );

  group('myHistory', () {
    test('falls back to tenant-scoped /api/sessions when /api/me/sessions is 404', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/sessions',
          queryParameters: any(named: 'queryParameters'))).thenThrow(httpStatus(404, '/api/me/sessions'));
      when(() => dio.get<Map<String, dynamic>>('/api/sessions',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => ok({'items': <dynamic>[], 'totalCount': 7}, '/api/sessions'));

      final result = await repo.myHistory();

      expect(result.totalCount, 7, reason: 'should return the tenant-scoped response');
      verify(() => dio.get<Map<String, dynamic>>('/api/sessions',
          queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('rethrows non-404 failures without falling back', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/sessions',
          queryParameters: any(named: 'queryParameters'))).thenThrow(httpStatus(500, '/api/me/sessions'));

      await expectLater(repo.myHistory(), throwsA(isA<ApiException>()));
      verifyNever(() => dio.get<Map<String, dynamic>>('/api/sessions',
          queryParameters: any(named: 'queryParameters')));
    });
  });

  group('myDetail', () {
    test('falls back to tenant-scoped detail when /api/me/sessions/{id} is 404', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/sessions/s1'))
          .thenThrow(httpStatus(404, '/api/me/sessions/s1'));
      when(() => dio.get<Map<String, dynamic>>('/api/sessions/s1')).thenAnswer((_) async => ok({
            'id': 's1',
            'traineeId': 't1',
            'source': 'plan',
            'status': 'completed',
            'startedAt': '2026-01-01T00:00:00Z',
            'exercises': <dynamic>[],
            'totalVolumeKg': 0,
          }, '/api/sessions/s1'));

      final result = await repo.myDetail('s1');

      expect(result.id, 's1');
    });
  });
}
