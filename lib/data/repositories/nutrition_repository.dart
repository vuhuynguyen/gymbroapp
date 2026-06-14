import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_call.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../domain/enums.dart';
import '../models/nutrition_models.dart';

/// The nutrition surface. Mirrors sessions
/// (`gymbro/docs/nutrition/API_AND_PERMISSIONS.md` §3):
///  * **Trainee reads + metrics** — `MeController` `/api/me/nutrition/*`, self-scoped & **cross-gym**
///    (NO `X-Tenant-Id`). `today`, `day`, `days`/`myHistory`, the check-in `metrics` GET and the
///    `metrics` POST stay here — a person eats one set of meals a day regardless of gym count.
///  * **Trainee item writes** — `/api/nutrition/log/*`, **tenant-scoped** (`X-Tenant-Id` required,
///    attached by `AuthInterceptor` from the active gym). The four mutating daily-log calls
///    (`setItemStatus`, `substitute`, `addItem`, `removeItem`) moved here to mirror workout sessions.
///  * **Coach** — `NutritionController` `/api/nutrition/*`, tenant-scoped (`X-Tenant-Id` required).
///
/// **Graceful fallback.** The backend nutrition surface is still rolling out; builds that predate it
/// 404 the whole `/api/me/nutrition/*` namespace. The read methods degrade to a no-plan day / empty
/// timeline on 404 (the same shim `session_repository.myHistory` uses for `/api/me/sessions`) so the
/// app shows the no-plan empty state instead of an error.
class NutritionRepository {
  NutritionRepository(this._dio);
  final Dio _dio;
  static const _uuid = Uuid();

  static const _me = '/api/me/nutrition';
  static const _coach = '/api/nutrition';
  static const _log = '/api/nutrition/log';

  // ── Trainee reads (self-scoped, cross-gym) ──────────────────────────────

  /// Today's log. `GET /api/me/nutrition/today` is lazily created server-side (never 204); on 404
  /// (surface not deployed) we synthesize a no-plan day so Today renders its empty state.
  Future<DailyNutritionLog> today() async {
    try {
      return await apiCall(() async {
        // Send the device-local date so "today" rolls over at the user's midnight, not UTC.
        final res = await _dio.get<Map<String, dynamic>>('$_me/today',
            queryParameters: {'date': _today()});
        return DailyNutritionLog.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return DailyNutritionLog.noPlan(_today());
      rethrow;
    }
  }

  /// A specific past day (read-only detail). 404 ⇒ no-plan placeholder for that date.
  Future<DailyNutritionLog> day(String date) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_me/days/$date');
        return DailyNutritionLog.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return DailyNutritionLog.noPlan(date);
      rethrow;
    }
  }

  /// The trainee's nutrition timeline (history). 404 ⇒ empty list (surface not deployed).
  Future<NutritionDayList> myHistory(
      {DateTime? from, DateTime? to, int page = 1, int pageSize = 30}) async {
    try {
      return await apiCall(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('$_me/days', queryParameters: {
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          'page': page,
          'pageSize': pageSize,
        });
        return NutritionDayList.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return NutritionDayList.empty;
      rethrow;
    }
  }

  /// The day's body check-in (latest weight + sleep). 404 ⇒ no readings yet.
  Future<DailyCheckin> checkin({DateTime? date}) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<dynamic>('$_me/metrics',
            queryParameters: {'date': _date(date ?? DateTime.now())});
        return DailyCheckin.fromMetrics(_metrics(res.data));
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return DailyCheckin.empty;
      rethrow;
    }
  }

  // ── Trainee item writes — tenant-scoped (`/api/nutrition/log/*`, X-Tenant-Id via active gym) ──

  /// Complete / skip a planned item: `POST /api/nutrition/log/items/status`. `missed` is server-only.
  Future<void> setItemStatus({
    required String date,
    required String itemId,
    required NutritionItemStatus status,
    String? note,
  }) =>
      apiCall(() async {
        await _dio.post<dynamic>('$_log/items/status', data: {
          'date': date,
          'itemId': itemId,
          'status': status.wire,
          if (note != null) 'note': note,
        });
      });

  /// Swap a planned item for a different food: `POST /api/nutrition/log/items/substitute`.
  Future<void> substitute({
    required String date,
    required String itemId,
    required String foodId,
    num? quantity,
    String? note,
  }) =>
      apiCall(() async {
        await _dio.post<dynamic>('$_log/items/substitute', data: {
          'date': date,
          'itemId': itemId,
          'foodId': foodId,
          if (quantity != null) 'quantity': quantity,
          if (note != null) 'note': note,
        });
      });

  /// Log an off-plan (ad-hoc) item: `POST /api/nutrition/log/items`. A catalog food sends its `foodId`;
  /// a **custom** food (`food.isCustom`, no catalog id) sends inline name/kind/serving/macros instead
  /// (the server creates a snapshot-only ad-hoc item — see the backend add-adhoc inline-custom path).
  Future<void> addItem({
    required String date,
    required Food food,
    required String mealName,
    num quantity = 1,
    String? note,
  }) {
    // Generate the idempotency id ONCE, outside the call, so a network-retry/replay reuses it and the server
    // dedups by (day, clientItemId) — a flaky "ate it" tap never double-logs.
    final clientItemId = _uuid.v4();
    return apiCall(() async {
        await _dio.post<dynamic>('$_log/items', data: {
          'date': date,
          'quantity': quantity,
          'mealName': mealName,
          'clientItemId': clientItemId,
          if (note != null) 'note': note,
          if (!food.isCustom)
            'foodId': food.id
          else ...{
            'customName': food.name,
            'customKind': food.kind.wire,
            if (food.servingLabel != null) 'servingLabel': food.servingLabel,
            if (food.energyKcal != null) 'energyKcal': food.energyKcal,
            if (food.proteinG != null) 'proteinG': food.proteinG,
            if (food.carbsG != null) 'carbsG': food.carbsG,
            if (food.fatG != null) 'fatG': food.fatG,
            if (food.fiberG != null) 'fiberG': food.fiberG,
          },
        });
      });
  }

  /// Remove an ad-hoc item: `DELETE /api/nutrition/log/items/{itemId}?date=`.
  Future<void> removeItem({required String date, required String itemId}) =>
      apiCall(() async => _dio.delete<dynamic>('$_log/items/$itemId',
          queryParameters: {'date': date}));

  /// Append a body metric (weight / sleep) — backs the daily check-in.
  Future<void> logMetric(MetricEntry entry) => apiCall(() async {
        // Stamp the device-local date so the metric lands on the local "today".
        final body = entry.toJson()..putIfAbsent('localDate', () => _today());
        await _dio.post<dynamic>('$_me/metrics', data: body);
      });

  // ── Food catalog (member read) ──────────────────────────────────────────

  Future<FoodList> searchFoods({String? search, FoodKind? kind}) async {
    try {
      return await apiCall(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('/api/foods', queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (kind != null) 'kind': kind.wire,
        });
        return FoodList.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return FoodList.empty;
      rethrow;
    }
  }

  // ── Coach reads (tenant-scoped) ─────────────────────────────────────────

  /// A client's adherence timeline (`NutritionLogViewAll`). 404 ⇒ empty.
  Future<NutritionDayList> clientLogs(String traineeId,
      {DateTime? from, DateTime? to}) async {
    try {
      return await apiCall(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('$_coach/logs', queryParameters: {
          'traineeId': traineeId,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
        });
        return NutritionDayList.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return NutritionDayList.empty;
      rethrow;
    }
  }

  /// Drill into one of a client's days. 404 ⇒ no-plan placeholder.
  Future<DailyNutritionLog> clientDay(String traineeId, String date) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_coach/logs/$date',
            queryParameters: {'traineeId': traineeId});
        return DailyNutritionLog.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return DailyNutritionLog.noPlan(date);
      rethrow;
    }
  }

  /// `GET /api/me/nutrition/metrics` may return a bare array or a `{items:[…]}` envelope.
  static List<MetricEntry> _metrics(Object? data) {
    final raw = data is Map ? data['items'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MetricEntry.fromJson)
        .toList(growable: false);
  }

  static String _today() => _date(DateTime.now());

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final nutritionRepositoryProvider = Provider<NutritionRepository>(
    (ref) => NutritionRepository(ref.read(apiDioProvider)));
