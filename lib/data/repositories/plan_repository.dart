import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_call.dart';
import '../../core/providers.dart';
import '../../domain/enums.dart';
import '../models/plan_models.dart';

class PlanRepository {
  PlanRepository(this._dio);
  final Dio _dio;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Assignment metadata for the current trainee (visibility flags, frequency, version status).
  /// `activeOnly` hides paused assignments — matches the Portal's start-workout picker.
  Future<PlanAssignmentList> myAssignments({bool activeOnly = true}) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/workout-plans/assignments',
          queryParameters: {'pageSize': 200, 'activeOnly': activeOnly},
        );
        return PlanAssignmentList.fromJson(res.data!);
      });

  /// For a Client this returns ONLY assigned plans (with names) — the server scopes it.
  Future<WorkoutPlanList> assignedPlans() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/workout-plans',
          queryParameters: {'pageSize': 200},
        );
        return WorkoutPlanList.fromJson(res.data!);
      });

  /// Plan detail. For a Client the server REDACTS per the assignment's visibility (Guided hide
  /// flags) — render as-is; never reimplement redaction client-side.
  Future<WorkoutPlanDetail> planDetail(String planId) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/workout-plans/$planId');
        return WorkoutPlanDetail.fromJson(res.data!);
      });

  // ── Coach (Owner) ──────────────────────────────────────────────────────
  /// Owner sees the latest version per template; the server scopes this by PlanViewAll.
  Future<WorkoutPlanList> listPlans({bool archived = false}) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/workout-plans',
          queryParameters: {'pageSize': 200, 'archived': archived},
        );
        return WorkoutPlanList.fromJson(res.data!);
      });

  /// All assignments for a specific trainee (Owner-only; the server 403s a client asking for others).
  Future<PlanAssignmentList> assignmentsForTrainee(String traineeId) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/workout-plans/assignments',
          queryParameters: {'traineeId': traineeId, 'pageSize': 200},
        );
        return PlanAssignmentList.fromJson(res.data!);
      });

  /// All assignments in the tenant (Owner) — used to enrich the client roster with plan + visibility.
  Future<PlanAssignmentList> allAssignments() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/workout-plans/assignments',
          queryParameters: {'pageSize': 200},
        );
        return PlanAssignmentList.fromJson(res.data!);
      });

  /// Pin the current plan version to a trainee. snapshotJson is omitted — the server records the
  /// per-session snapshot at session start (and Blind seeds none), so it is not needed at assign time.
  Future<String> createAssignment({
    required String traineeId,
    required String planId,
    required DateTime startDate,
    required int frequencyDaysPerWeek,
    required PlanVisibilityMode visibilityMode,
    bool hideExercises = false,
    bool hideSetsReps = false,
    bool hideFutureWorkouts = false,
    bool disableTraineeEditing = false,
  }) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/workout-plans/assignments',
          data: {
            'traineeId': traineeId,
            'planId': planId,
            'startDate': _date(startDate),
            'frequencyDaysPerWeek': frequencyDaysPerWeek,
            'visibilityMode': visibilityMode.wire,
            'hideExercises': hideExercises,
            'hideSetsReps': hideSetsReps,
            'hideFutureWorkouts': hideFutureWorkouts,
            'disableTraineeEditing': disableTraineeEditing,
          },
        );
        return res.data!['id'].toString();
      });

  Future<void> setAssignmentActive(String assignmentId, bool active) => apiCall(() async {
        await _dio.put<dynamic>(
          '/api/workout-plans/assignments/$assignmentId/${active ? 'resume' : 'pause'}',
        );
      });

  /// Re-point a live assignment to the newest plan version (snapshot preserved server-side).
  Future<void> applyLatest(String assignmentId) => apiCall(() async {
        await _dio.put<dynamic>(
          '/api/workout-plans/assignments/$assignmentId/apply-latest',
          data: const <String, dynamic>{},
        );
      });
}

final planRepositoryProvider =
    Provider<PlanRepository>((ref) => PlanRepository(ref.read(apiDioProvider)));
