import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_call.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../domain/enums.dart';
import '../models/session_models.dart';

/// Every endpoint of `SessionController`. The server enforces the state machine
/// (InProgress → Completed/Abandoned), the single-active-session rule, and visibility — the client
/// just calls and surfaces the typed result/error.
class SessionRepository {
  SessionRepository(this._dio);
  final Dio _dio;
  static const _base = '/api/sessions';

  /// `GET /sessions/active` → 204 means "no active session" (null), not an error.
  Future<ActiveSession?> active() => apiCall(() async {
        final res = await _dio.get<dynamic>('$_base/active');
        if (res.statusCode == 204 || res.data == null || res.data == '') {
          return null;
        }
        return ActiveSession.fromJson(res.data as Map<String, dynamic>);
      });

  Future<SessionList> list({
    String? traineeId,
    DateTime? from,
    DateTime? to,
    SessionStatus? status,
    String? planAssignmentId,
    int page = 1,
    int pageSize = 20,
  }) =>
      apiCall(() async {
        final res =
            await _dio.get<Map<String, dynamic>>(_base, queryParameters: {
          if (traineeId != null) 'traineeId': traineeId,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          if (status != null) 'status': status.wire,
          if (planAssignmentId != null) 'planAssignmentId': planAssignmentId,
          'page': page,
          'pageSize': pageSize,
        });
        return SessionList.fromJson(res.data!);
      });

  Future<SessionDetail> detail(String sessionId) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('$_base/$sessionId');
        return SessionDetail.fromJson(res.data!);
      });

  // ── Unified personal training (cross-gym, self-scoped — NO X-Tenant-Id) ──
  // The trainee's own Workout Log / history / detail aggregates across every gym they belong to.
  // Tenant-scoped `list`/`detail` above stay for the coach's WorkoutLogViewAll views.

  Future<SessionList> myHistory({
    DateTime? from,
    DateTime? to,
    SessionStatus? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      return await apiCall(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('/api/me/sessions', queryParameters: {
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          if (status != null) 'status': status.wire,
          'page': page,
          'pageSize': pageSize,
        });
        return SessionList.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      // Backend-compat shim: API builds that predate `MeController` 404 the whole `/api/me/*`
      // surface. Fall back to the tenant-scoped history so the app works during the API rollout
      // (single active gym instead of cross-gym aggregation — degrades gracefully).
      if (e.isNotFound) {
        return list(
            from: from, to: to, status: status, page: page, pageSize: pageSize);
      }
      rethrow;
    }
  }

  Future<SessionDetail> myDetail(String sessionId) async {
    try {
      return await apiCall(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('/api/me/sessions/$sessionId');
        return SessionDetail.fromJson(res.data!);
      });
    } on ApiException catch (e) {
      // See `myHistory` — fall back to the tenant-scoped detail when `/api/me/*` isn't deployed.
      if (e.isNotFound) return detail(sessionId);
      rethrow;
    }
  }

  Future<SessionStartResult> start(StartSessionRequest body) =>
      apiCall(() async {
        final res =
            await _dio.post<Map<String, dynamic>>(_base, data: body.toJson());
        return SessionStartResult.fromJson(res.data!);
      });

  Future<PerformedExercise> addExercise(
          String sessionId, AddExerciseRequest body) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$sessionId/exercises',
          data: body.toJson(),
        );
        return PerformedExercise.fromJson(res.data!);
      });

  /// Skip or substitute a performed exercise (`UpdatePerformedExerciseCommand`).
  /// Skip requires zero logged sets on that exercise (else the server returns 409).
  Future<void> updateExercise(
    String sessionId,
    String exerciseId,
    UpdateExerciseRequest body,
  ) =>
      apiCall(() async {
        await _dio.put<dynamic>(
          '$_base/$sessionId/exercises/$exerciseId',
          data: body.toJson(),
        );
      });

  Future<PerformedSet> logSet(
          String sessionId, String exerciseId, LogSetRequest body) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '$_base/$sessionId/exercises/$exerciseId/sets',
          data: body.toJson(),
        );
        return PerformedSet.fromJson(res.data!);
      });

  Future<void> editSet(
    String sessionId,
    String exerciseId,
    String setId,
    EditSetRequest body,
  ) =>
      apiCall(() async {
        await _dio.put<dynamic>(
          '$_base/$sessionId/exercises/$exerciseId/sets/$setId',
          data: body.toJson(),
        );
      });

  Future<void> deleteSet(String sessionId, String exerciseId, String setId) =>
      apiCall(() async {
        await _dio.delete<dynamic>(
            '$_base/$sessionId/exercises/$exerciseId/sets/$setId');
      });

  /// Reorders the exercise's sets to match [orderedSetIds] (full list, in the desired order); the server
  /// renumbers `setNumber` accordingly.
  Future<void> reorderSets(
          String sessionId, String exerciseId, List<String> orderedSetIds) =>
      apiCall(() async {
        await _dio.put<dynamic>(
          '$_base/$sessionId/exercises/$exerciseId/sets/order',
          data: {'setIds': orderedSetIds},
        );
      });

  /// Fully removes an exercise from the session; the server cascade-deletes its logged sets.
  Future<void> deleteExercise(String sessionId, String exerciseId) =>
      apiCall(() async {
        await _dio.delete<dynamic>('$_base/$sessionId/exercises/$exerciseId');
      });

  Future<void> complete(String sessionId, CompleteSessionRequest body) =>
      apiCall(() async {
        await _dio.post<dynamic>('$_base/$sessionId/complete',
            data: body.toJson());
      });

  Future<void> abandon(String sessionId, {String? notes}) => apiCall(() async {
        await _dio.post<dynamic>(
          '$_base/$sessionId/abandon',
          data: {if (notes != null) 'notes': notes},
        );
      });

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final sessionRepositoryProvider = Provider<SessionRepository>(
    (ref) => SessionRepository(ref.read(apiDioProvider)));
