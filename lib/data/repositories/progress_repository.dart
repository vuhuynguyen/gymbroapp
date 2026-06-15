import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_call.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../models/progress_models.dart';

/// The trainee Progress home is one self-scoped, cross-gym read (`GET /api/me/progress/overview`,
/// NO `X-Tenant-Id`). The server computes adherence + consistency + top-lift direction + a PR teaser,
/// so the client never re-derives them — see gymbro/docs/progress/API-CONTRACTS.md §1.
class ProgressRepository {
  ProgressRepository(this._dio);
  final Dio _dio;

  /// [weeks] selects the look-back window (the Progress page's period control), threaded through as
  /// `?weeks=N`; null leaves it off so the server applies its default window.
  Future<ProgressOverview> overview({int? weeks}) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/progress/overview',
          queryParameters: {if (weeks != null) 'weeks': weeks},
        );
        return ProgressOverview.fromJson(res.data ?? const {});
      });
    } on ApiException catch (e) {
      // Backend-compat shim (mirrors `SessionRepository.myHistory`): API builds that predate this
      // `MeController` action 404 the whole `/api/me/*` surface. There's no tenant-scoped fallback
      // for this aggregate, so degrade to an empty-but-valid overview (the screen renders the
      // new-user/empty states) rather than erroring the tab during the API rollout.
      if (e.isNotFound) {
        return ProgressOverview.fromJson(const {});
      }
      rethrow;
    }
  }

  /// Full per-lift e1RM series for the strength drill-down (API-CONTRACTS §2). Self-scoped,
  /// cross-gym (NO `X-Tenant-Id`); PR markers are derived server-side from the series. 404-graceful
  /// like [overview]: an API build that predates this action degrades to an empty-but-valid series
  /// (the detail screen shows its "not enough data yet" state) rather than erroring the drill-down.
  ///
  /// [from]/[to] bound the series to the Progress page's selected period (`from = today − N weeks`,
  /// `to = today`); each is sent as a `yyyy-MM-dd` query param when present, so the drill-down trend
  /// matches the window the home page is showing. Omitting both lets the server use its default range.
  Future<ExerciseE1rmSeries> exerciseE1rmSeries(
    String exerciseId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/exercises/$exerciseId/e1rm-series',
          queryParameters: {
            if (from != null) 'from': _isoDay(from),
            if (to != null) 'to': _isoDay(to),
          },
        );
        return ExerciseE1rmSeries.fromJson(res.data ?? const {});
      });
    } on ApiException catch (e) {
      if (e.isNotFound) {
        return ExerciseE1rmSeries.fromJson({'exerciseId': exerciseId});
      }
      rethrow;
    }
  }

  /// Every performed lift over the window for the Strength section's muscle-group / exercise filtering
  /// (`GET /api/me/exercises/strength-lifts`). Self-scoped, cross-gym (NO `X-Tenant-Id`,
  /// `QueryOwnAcrossGyms`); windowed by [weeks] exactly like [overview] and sorted by current e1RM desc
  /// server-side. The honesty gate lives in the query — a lift with `hasTrend == false` carries no
  /// meaningful direction, so the client renders e1RM + session count only.
  ///
  /// [weeks] threads the Progress period control through as `?weeks=N` (the server clamps 4..52,
  /// default 12). [muscleGroup] optionally narrows server-side to one camelCase group; the client also
  /// filters the already-fetched list client-side for the chip row (so switching chips needs no
  /// refetch), but the param is supported for a future server-narrowed fetch. 404-graceful like
  /// [overview]: an API build that predates this action degrades to an empty-but-valid list (the
  /// Strength section shows its honest empty state) rather than erroring the tab.
  Future<StrengthLifts> strengthLifts({int? weeks, String? muscleGroup}) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/exercises/strength-lifts',
          queryParameters: {
            if (weeks != null) 'weeks': weeks,
            if (muscleGroup != null && muscleGroup.isNotEmpty)
              'muscleGroup': muscleGroup,
          },
        );
        return StrengthLifts.fromJson(res.data ?? const {});
      });
    } on ApiException catch (e) {
      if (e.isNotFound) {
        return StrengthLifts.fromJson(const {});
      }
      rethrow;
    }
  }

  /// Body-metric trend series (API-CONTRACTS §3) — bodyweight today. Self-scoped, cross-gym.
  /// 404-graceful: until the new `MetricEntry` range endpoint ships, this surface 404s — degrade to
  /// an empty-but-valid series so the home Body section shows its log-your-weight invite, never an
  /// error. [type] is matched case-insensitively / normalized server-side.
  ///
  /// [from] overrides the server's default window. Bodyweight uses the default (a recent *trend*);
  /// goal-weight passes a far-past [from] so the current goal is found however long ago it was set —
  /// a goal is a long-lived setting, not a 12-week series.
  Future<MetricSeries> metricSeries(String type, {DateTime? from}) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/progress/metrics/series',
          queryParameters: {
            'type': type,
            if (from != null) 'from': _isoDay(from),
          },
        );
        return MetricSeries.fromJson(res.data ?? const {});
      });
    } on ApiException catch (e) {
      if (e.isNotFound) {
        return MetricSeries.fromJson({'type': type});
      }
      rethrow;
    }
  }

  /// Records the trainee's current goal weight (Phase 3 / Decision **D12**). No migration: goal-weight
  /// rides the existing free-text `MetricEntry` as `Type="goal_weight"` (latest entry = current goal),
  /// written via the same `POST /api/me/nutrition/metrics` the daily check-in already uses. The Body
  /// section reads it back through [metricSeries]`('goal_weight')` and overlays the goal line.
  ///
  /// Not 404-shimmed: this is a deliberate user write — if the endpoint is genuinely missing the sheet
  /// must surface the failure (a silently-swallowed "saved" would be a lie), so the [ApiException]
  /// propagates to the caller.
  Future<void> setGoalWeight(double kg) => apiCall(() async {
        await _dio.post<dynamic>('/api/me/nutrition/metrics', data: {
          'type': 'goal_weight',
          'value': kg,
          'unit': 'kg',
        });
      });

  /// Recent nutrition adherence for the home Body→nutrition card (API-CONTRACTS §5 / Decision
  /// **D13**). Self-scoped, cross-gym (NO `X-Tenant-Id`). 404-graceful like [overview]: this endpoint
  /// ships with the nutrition program, so older API builds 404 it — degrade to an empty-but-valid
  /// `hasPlan: false` payload so the card shows its "follow a meal plan" invite, never an error.
  ///
  /// [from]/[to] are optional local-day bounds (the endpoint accepts `?from=&to=`, defaulting to a
  /// trailing 4 weeks). The Progress period control passes its window so the calories trend matches
  /// the selected period; omitting both keeps the server default.
  Future<NutritionAdherence> nutritionAdherence({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/progress/nutrition-adherence',
          queryParameters: {
            if (from != null) 'from': _isoDay(from),
            if (to != null) 'to': _isoDay(to),
          },
        );
        return NutritionAdherence.fromJson(res.data ?? const {});
      });
    } on ApiException catch (e) {
      if (e.isNotFound) {
        return NutritionAdherence.fromJson(const {});
      }
      rethrow;
    }
  }
}

/// `DateOnly` wire format (`yyyy-MM-dd`) for the `from`/`to` query params.
String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => ProgressRepository(ref.read(apiDioProvider)));
