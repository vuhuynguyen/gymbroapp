import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_call.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../models/coach_models.dart';
import '../models/progress_models.dart';

/// The coach Progress surface (Phase 2b) — two TENANT-SCOPED reads on the coach's own gym. Both go
/// through [apiDioProvider], so the `AuthInterceptor` attaches the membership-validated `X-Tenant-Id`
/// header exactly like every other coach read (`SessionRepository.list`, the assignment calls). The
/// server gates on `WorkoutLogViewAll` + `ResourceAccessGuard` and runs with the EF tenant filter ON
/// — a separate handler from the trainee self-scoped path, never `QueryOwnAcrossGyms`
/// ([FEASIBILITY R2] / COACH-VS-TRAINEE.md §4). See gymbro/docs/progress/API-CONTRACTS.md §4.
class CoachProgressRepository {
  CoachProgressRepository(this._dio);
  final Dio _dio;

  /// `GET /api/clients/progress/roster` — the at-risk-first roster (own gym only). 404-graceful like
  /// the trainee reads: an API build that predates this action degrades to an empty-but-valid roster
  /// (the screen shows its "No clients yet" empty state) rather than erroring the coach home.
  Future<Roster> roster() async {
    try {
      return await apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/clients/progress/roster');
        return Roster.fromJson(res.data ?? const {});
      });
    } on ApiException catch (e) {
      if (e.isNotFound) return Roster.fromJson(const {});
      rethrow;
    }
  }

  /// `GET /api/clients/{traineeId}/progress/strength` — the per-client e1RM trend, built from the
  /// coach's TENANT-SCOPED sessions (own gym). Same shape as the trainee `/api/me/exercises/{id}/
  /// e1rm-series` (§2), so it reuses [ExerciseE1rmSeries]. The server returns 403/404 if `traineeId`
  /// isn't a member of the active tenant — never silently rescoped to self. We surface 403/404 as a
  /// real error (don't mask a leak/forbidden as empty); other not-deployed shapes aren't masked here
  /// because the strength list has no safe empty fallback that wouldn't hide an access boundary.
  Future<List<ExerciseE1rmSeries>> clientStrength(String traineeId, {int take = 6}) {
    return apiCall(() async {
      final res = await _dio.get<List<dynamic>>(
        '/api/clients/$traineeId/progress/strength',
        queryParameters: {'take': take},
      );
      final list = res.data ?? const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>) ExerciseE1rmSeries.fromJson(e),
      ];
    });
  }

  /// `GET /api/clients/{traineeId}/progress/load` — the per-client acute-vs-chronic workload, built
  /// from the coach's TENANT-SCOPED sessions (own gym only). The server returns 403/404 if `traineeId`
  /// isn't a member of the active tenant — never silently rescoped to self. We surface 403/404 as a
  /// real error (don't mask an access-boundary leak as empty), exactly like [clientStrength]; there's
  /// no safe empty fallback that wouldn't hide a forbidden/leak. See API-CONTRACTS.md (Decision D14).
  Future<AcuteChronicLoad> clientLoad(String traineeId) {
    return apiCall(() async {
      final res = await _dio
          .get<Map<String, dynamic>>('/api/clients/$traineeId/progress/load');
      return AcuteChronicLoad.fromJson(res.data ?? const {});
    });
  }
}

final coachProgressRepositoryProvider = Provider<CoachProgressRepository>(
    (ref) => CoachProgressRepository(ref.read(apiDioProvider)));
