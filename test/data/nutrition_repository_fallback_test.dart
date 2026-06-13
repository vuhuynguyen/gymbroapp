import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/core/network/api_exception.dart';
import 'package:gymbroapp/data/models/nutrition_models.dart';
import 'package:gymbroapp/data/repositories/nutrition_repository.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// The nutrition surface is still rolling out — builds that predate it 404 the whole
/// `/api/me/nutrition/*` namespace. The reads must degrade to a no-plan day / empty timeline on 404
/// (the same graceful shim `session_repository.myHistory` uses), but must NOT swallow other failures.
void main() {
  late _MockDio dio;
  late NutritionRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = NutritionRepository(dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> data, String path) =>
      Response(data: data, statusCode: 200, requestOptions: RequestOptions(path: path));

  DioException httpStatus(int code, String path) => DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(statusCode: code, requestOptions: RequestOptions(path: path)),
      );

  group('today', () {
    test('404 ⇒ a synthesized no-plan day (not an error)', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/nutrition/today',
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(httpStatus(404, '/api/me/nutrition/today'));

      final log = await repo.today();

      expect(log.hasPlan, isFalse);
      expect(log.meals, isEmpty);
      expect(log.adherencePct, 100, reason: 'no planned items ⇒ 100%');
    });

    test('rethrows non-404 failures without falling back', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/nutrition/today',
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(httpStatus(500, '/api/me/nutrition/today'));

      await expectLater(repo.today(), throwsA(isA<ApiException>()));
    });

    test('parses a populated day', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/nutrition/today',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => ok({
            'id': 'd1',
            'localDate': '2026-06-10',
            'status': 'open',
            'source': 'fromAssignment',
            'hasPlan': true,
            'meals': [
              {
                'name': 'Breakfast',
                'scheduledTime': '08:00:00',
                'items': [
                  {'id': 'i1', 'planMealItemId': 'p1', 'foodId': 'f1', 'foodName': 'Oatmeal', 'status': 'completed'},
                  {'id': 'i2', 'planMealItemId': 'p2', 'foodId': 'f2', 'foodName': 'Eggs', 'status': 'planned'},
                ],
              },
            ],
          }, '/api/me/nutrition/today'));

      final log = await repo.today();

      expect(log.hasPlan, isTrue);
      expect(log.plannedCount, 2);
      expect(log.completedCount, 1);
      expect(log.adherencePct, 50);
    });
  });

  group('day', () {
    test('404 ⇒ no-plan placeholder for that date', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/nutrition/days/2026-06-01'))
          .thenThrow(httpStatus(404, '/api/me/nutrition/days/2026-06-01'));

      final log = await repo.day('2026-06-01');

      expect(log.hasPlan, isFalse);
      expect(log.localDate, '2026-06-01');
    });
  });

  group('myHistory', () {
    test('404 ⇒ empty timeline', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/nutrition/days',
          queryParameters: any(named: 'queryParameters'))).thenThrow(httpStatus(404, '/api/me/nutrition/days'));

      final list = await repo.myHistory();

      expect(list.items, isEmpty);
    });

    test('rethrows a 403 (no graceful fallback)', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/me/nutrition/days',
          queryParameters: any(named: 'queryParameters'))).thenThrow(httpStatus(403, '/api/me/nutrition/days'));

      await expectLater(repo.myHistory(), throwsA(isA<ApiException>()));
    });
  });

  group('searchFoods', () {
    test('404 ⇒ empty catalog', () async {
      when(() => dio.get<Map<String, dynamic>>('/api/foods',
          queryParameters: any(named: 'queryParameters'))).thenThrow(httpStatus(404, '/api/foods'));

      final list = await repo.searchFoods(search: 'oats');

      expect(list.items, isEmpty);
    });
  });

  // The backend now persists off-plan items WITHOUT an assignment (self-train) and returns 201 with
  // the new item id. Dio treats 201 as success (no throw), so the write completes and the controller
  // keeps the optimistic row — no 404 fallback masking the success.
  //
  // Item writes are TENANT-SCOPED (`/api/nutrition/log/*`, X-Tenant-Id attached by the interceptor
  // from the active gym), mirroring workout sessions — NOT the self-scoped `/api/me/nutrition/*`
  // namespace the reads + metrics use.
  group('addItem (off-plan POST /api/nutrition/log/items)', () {
    Response<dynamic> created(String path) => Response(
        data: {'itemId': 'srv-1'},
        statusCode: 201,
        requestOptions: RequestOptions(path: path));

    test('hits the tenant-scoped /api/nutrition/log base, not /api/me/nutrition', () async {
      when(() => dio.post<dynamic>('/api/nutrition/log/items', data: any(named: 'data')))
          .thenAnswer((_) async => created('/api/nutrition/log/items'));

      await repo.addItem(
        date: '2026-06-11',
        food: const Food(id: 'f9', name: 'Banana', kind: FoodKind.food, energyKcal: 105),
        mealName: 'Off-plan',
      );

      verify(() => dio.post<dynamic>('/api/nutrition/log/items', data: any(named: 'data')))
          .called(1);
      verifyNever(() => dio.post<dynamic>('/api/me/nutrition/items', data: any(named: 'data')));
    });

    test('catalog food sends foodId + date + meal (AddAdhocNutritionItemRequest shape)', () async {
      Map<String, dynamic>? sent;
      when(() => dio.post<dynamic>('/api/nutrition/log/items', data: any(named: 'data')))
          .thenAnswer((inv) async {
        sent = inv.namedArguments[#data] as Map<String, dynamic>;
        return created('/api/nutrition/log/items');
      });

      await repo.addItem(
        date: '2026-06-11',
        food: const Food(id: 'f9', name: 'Banana', kind: FoodKind.food, energyKcal: 105),
        mealName: 'Off-plan',
        quantity: 2,
      );

      expect(sent, isNotNull);
      expect(sent!['date'], '2026-06-11');
      expect(sent!['foodId'], 'f9');
      expect(sent!['quantity'], 2);
      expect(sent!['mealName'], 'Off-plan');
      // A catalog food must NOT send inline custom fields.
      expect(sent!.containsKey('customName'), isFalse);
    });

    test('custom food sends inline Custom* fields, not a foodId', () async {
      Map<String, dynamic>? sent;
      when(() => dio.post<dynamic>('/api/nutrition/log/items', data: any(named: 'data')))
          .thenAnswer((inv) {
        sent = inv.namedArguments[#data] as Map<String, dynamic>;
        return Future.value(created('/api/nutrition/log/items'));
      });

      await repo.addItem(
        date: '2026-06-11',
        food: const Food(
          id: 'mf-local',
          name: 'Grandma stew',
          kind: FoodKind.food,
          servingLabel: '1 bowl',
          energyKcal: 400,
          proteinG: 30,
          carbsG: 25,
          fatG: 18,
          fiberG: 6,
          isCustom: true,
        ),
        mealName: 'Dinner',
      );

      expect(sent!.containsKey('foodId'), isFalse);
      expect(sent!['customName'], 'Grandma stew');
      expect(sent!['customKind'], FoodKind.food.wire);
      expect(sent!['servingLabel'], '1 bowl');
      expect(sent!['energyKcal'], 400);
      expect(sent!['proteinG'], 30);
      expect(sent!['fiberG'], 6);
    });
  });

  // The other three mutating daily-log calls are likewise tenant-scoped under /api/nutrition/log.
  group('item writes are tenant-scoped (/api/nutrition/log/items*)', () {
    Response<dynamic> okv(String path) => Response<dynamic>(
        data: {'ok': true}, statusCode: 200, requestOptions: RequestOptions(path: path));

    test('setItemStatus → POST /api/nutrition/log/items/status', () async {
      when(() => dio.post<dynamic>('/api/nutrition/log/items/status', data: any(named: 'data')))
          .thenAnswer((_) async => okv('/api/nutrition/log/items/status'));

      await repo.setItemStatus(
          date: '2026-06-11', itemId: 'i1', status: NutritionItemStatus.completed);

      verify(() => dio.post<dynamic>('/api/nutrition/log/items/status', data: any(named: 'data')))
          .called(1);
      verifyNever(
          () => dio.post<dynamic>('/api/me/nutrition/items/status', data: any(named: 'data')));
    });

    test('substitute → POST /api/nutrition/log/items/substitute', () async {
      when(() => dio.post<dynamic>('/api/nutrition/log/items/substitute', data: any(named: 'data')))
          .thenAnswer((_) async => okv('/api/nutrition/log/items/substitute'));

      await repo.substitute(date: '2026-06-11', itemId: 'i1', foodId: 'f2', quantity: 1);

      verify(() =>
              dio.post<dynamic>('/api/nutrition/log/items/substitute', data: any(named: 'data')))
          .called(1);
    });

    test('removeItem → DELETE /api/nutrition/log/items/{id}?date=', () async {
      when(() => dio.delete<dynamic>('/api/nutrition/log/items/i1',
          queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => okv('/api/nutrition/log/items/i1'),
      );

      await repo.removeItem(date: '2026-06-11', itemId: 'i1');

      verify(() => dio.delete<dynamic>('/api/nutrition/log/items/i1',
          queryParameters: any(named: 'queryParameters'))).called(1);
      verifyNever(() => dio.delete<dynamic>('/api/me/nutrition/items/i1',
          queryParameters: any(named: 'queryParameters')));
    });
  });

  group('logMetric (POST /metrics) — stays self-scoped on /api/me/nutrition', () {
    test('sends {type,value,unit,localDate} matching LogMetricEntryRequest', () async {
      Map<String, dynamic>? sent;
      when(() => dio.post<dynamic>('/api/me/nutrition/metrics', data: any(named: 'data')))
          .thenAnswer((inv) {
        sent = inv.namedArguments[#data] as Map<String, dynamic>;
        return Future.value(Response<dynamic>(
            data: {'logged': true},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/me/nutrition/metrics')));
      });

      await repo.logMetric(const MetricEntry(
          type: 'weight', value: 81.4, unit: 'kg', localDate: '2026-06-11'));

      expect(sent!['type'], 'weight');
      expect(sent!['value'], 81.4);
      expect(sent!['unit'], 'kg');
      expect(sent!['localDate'], '2026-06-11');
    });
  });

  group('checkin (GET /metrics)', () {
    test('parses {items:[…]} newest-first into latest weight + sleep', () async {
      when(() => dio.get<dynamic>('/api/me/nutrition/metrics',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response<dynamic>(
                requestOptions: RequestOptions(path: '/api/me/nutrition/metrics'),
                statusCode: 200,
                // Newest first (server OrderByDescending(loggedAtUtc)): the FIRST of each type wins.
                data: {
                  'items': [
                    {'type': 'weight', 'value': 80.0, 'unit': 'kg', 'localDate': '2026-06-11', 'loggedAtUtc': '2026-06-11T18:00:00Z'},
                    {'type': 'sleep', 'value': 7.5, 'unit': 'h', 'localDate': '2026-06-11', 'loggedAtUtc': '2026-06-11T08:00:00Z'},
                    {'type': 'weight', 'value': 82.0, 'unit': 'kg', 'localDate': '2026-06-11', 'loggedAtUtc': '2026-06-11T06:00:00Z'},
                  ],
                },
              ));

      final c = await repo.checkin(date: DateTime(2026, 6, 11));

      expect(c.weightKg, 80.0, reason: 'newest weight entry, not the older 82.0');
      expect(c.sleepHours, 7.5);
    });

    test('404 ⇒ empty check-in (older deployments)', () async {
      when(() => dio.get<dynamic>('/api/me/nutrition/metrics',
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(httpStatus(404, '/api/me/nutrition/metrics'));

      final c = await repo.checkin();

      expect(c.isEmpty, isTrue);
    });
  });
}
