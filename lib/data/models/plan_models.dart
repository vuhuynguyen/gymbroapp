import '../../core/utils/json.dart';
import '../../domain/enums.dart';

/// Mirrors `Modules.WorkoutPlan.Application.DTOs`.

class WorkoutPlanSummary {
  const WorkoutPlanSummary({
    required this.id,
    required this.templateId,
    required this.version,
    required this.name,
    this.description,
    this.durationWeeks,
    this.workoutsPerWeek,
    this.createdOnUtc,
    required this.workoutCount,
    required this.isArchived,
  });

  final String id;
  final String templateId;
  final int version;
  final String name;
  final String? description;
  final int? durationWeeks;
  final int? workoutsPerWeek;
  final DateTime? createdOnUtc;
  final int workoutCount;
  final bool isArchived;

  factory WorkoutPlanSummary.fromJson(Map<String, dynamic> j) => WorkoutPlanSummary(
        id: j['id'].toString(),
        templateId: j['templateId'].toString(),
        version: asInt(j['version']) ?? 1,
        name: asString(j['name']) ?? '',
        description: asString(j['description']),
        durationWeeks: asInt(j['durationWeeks']),
        workoutsPerWeek: asInt(j['workoutsPerWeek']),
        createdOnUtc: asDate(j['createdOnUtc']),
        workoutCount: asInt(j['workoutCount']) ?? 0,
        isArchived: asBool(j['isArchived']),
      );
}

class WorkoutPlanList {
  const WorkoutPlanList({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<WorkoutPlanSummary> items;
  final int page;
  final int pageSize;
  final int totalCount;

  factory WorkoutPlanList.fromJson(Map<String, dynamic> j) => WorkoutPlanList(
        items: asList(j['items'], WorkoutPlanSummary.fromJson),
        page: asInt(j['page']) ?? 1,
        pageSize: asInt(j['pageSize']) ?? 10,
        totalCount: asInt(j['totalCount']) ?? 0,
      );
}

/// A prescribed set. Under `Guided` + `HideSetsReps`, targets arrive null (count/type/rest kept).
class PlanSetDetail {
  const PlanSetDetail({
    required this.id,
    required this.order,
    required this.setType,
    this.targetReps,
    this.targetWeightKg,
    this.targetRpe,
    this.targetDurationSeconds,
    required this.restSeconds,
  });

  final String id;
  final int order;
  final PlanSetType setType;
  final int? targetReps;
  final double? targetWeightKg;
  final int? targetRpe;
  final int? targetDurationSeconds;
  final int restSeconds;

  /// True when the coach redacted the prescription (Guided + HideSetsReps).
  bool get targetsHidden =>
      targetReps == null && targetWeightKg == null && targetRpe == null && targetDurationSeconds == null;

  factory PlanSetDetail.fromJson(Map<String, dynamic> j) => PlanSetDetail(
        id: j['id'].toString(),
        order: asInt(j['order']) ?? 0,
        setType: PlanSetType.parse(j['setType']),
        targetReps: asInt(j['targetReps']),
        targetWeightKg: asDouble(j['targetWeightKg']),
        targetRpe: asInt(j['targetRpe']),
        targetDurationSeconds: asInt(j['targetDurationSeconds']),
        restSeconds: asInt(j['restSeconds']) ?? 0,
      );
}

class PlanWorkoutExerciseDetail {
  const PlanWorkoutExerciseDetail({
    required this.id,
    required this.exerciseId,
    this.exerciseName,
    required this.order,
    required this.sets,
    this.supersetGroupId,
  });

  final String id;

  /// `Guid.Empty` ("000…0") when the coach hid exercises (Guided + HideExercises).
  final String exerciseId;
  final String? exerciseName;
  final int order;
  final List<PlanSetDetail> sets;

  /// Exercises in a workout that share a non-null group id are prescribed as a superset (performed
  /// in rotation, rest after the round). Null = a standalone exercise.
  final String? supersetGroupId;

  static const _emptyGuid = '00000000-0000-0000-0000-000000000000';

  /// True when the coach redacted the exercise identity in the plan preview.
  bool get exerciseHidden => exerciseName == null || exerciseId == _emptyGuid;

  factory PlanWorkoutExerciseDetail.fromJson(Map<String, dynamic> j) => PlanWorkoutExerciseDetail(
        id: j['id'].toString(),
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        order: asInt(j['order']) ?? 0,
        sets: asList(j['sets'], PlanSetDetail.fromJson),
        supersetGroupId: asString(j['supersetGroupId']),
      );
}

class PlanWorkoutDetail {
  const PlanWorkoutDetail({
    required this.id,
    required this.order,
    required this.name,
    required this.exercises,
  });

  final String id;
  final int order;
  final String name;
  final List<PlanWorkoutExerciseDetail> exercises;

  factory PlanWorkoutDetail.fromJson(Map<String, dynamic> j) => PlanWorkoutDetail(
        id: j['id'].toString(),
        order: asInt(j['order']) ?? 0,
        name: asString(j['name']) ?? '',
        exercises: asList(j['exercises'], PlanWorkoutExerciseDetail.fromJson),
      );
}

class WorkoutPlanDetail {
  const WorkoutPlanDetail({
    required this.id,
    required this.templateId,
    required this.version,
    required this.name,
    this.description,
    this.durationWeeks,
    this.workoutsPerWeek,
    this.createdOnUtc,
    required this.workouts,
  });

  final String id;
  final String templateId;
  final int version;
  final String name;
  final String? description;
  final int? durationWeeks;
  final int? workoutsPerWeek;
  final DateTime? createdOnUtc;
  final List<PlanWorkoutDetail> workouts;

  factory WorkoutPlanDetail.fromJson(Map<String, dynamic> j) => WorkoutPlanDetail(
        id: j['id'].toString(),
        templateId: j['templateId'].toString(),
        version: asInt(j['version']) ?? 1,
        name: asString(j['name']) ?? '',
        description: asString(j['description']),
        durationWeeks: asInt(j['durationWeeks']),
        workoutsPerWeek: asInt(j['workoutsPerWeek']),
        createdOnUtc: asDate(j['createdOnUtc']),
        workouts: asList(j['workouts'], PlanWorkoutDetail.fromJson),
      );
}

/// `GET /api/workout-plans/assignments` → PlanAssignmentSummaryDto[].
class PlanAssignmentSummary {
  const PlanAssignmentSummary({
    required this.id,
    required this.traineeId,
    required this.planId,
    required this.planVersion,
    required this.latestPlanVersion,
    required this.hasNewerVersion,
    this.startDate,
    required this.frequencyDaysPerWeek,
    required this.visibilityMode,
    required this.hideExercises,
    required this.hideSetsReps,
    required this.hideFutureWorkouts,
    required this.disableTraineeEditing,
    required this.isActive,
  });

  final String id;
  final String traineeId;
  final String planId;
  final int planVersion;
  final int latestPlanVersion;
  final bool hasNewerVersion;
  final DateTime? startDate;
  final int frequencyDaysPerWeek;
  final PlanVisibilityMode visibilityMode;
  final bool hideExercises;
  final bool hideSetsReps;
  final bool hideFutureWorkouts;
  final bool disableTraineeEditing;
  final bool isActive;

  factory PlanAssignmentSummary.fromJson(Map<String, dynamic> j) => PlanAssignmentSummary(
        id: j['id'].toString(),
        traineeId: j['traineeId'].toString(),
        planId: j['planId'].toString(),
        planVersion: asInt(j['planVersion']) ?? 1,
        latestPlanVersion: asInt(j['latestPlanVersion']) ?? 1,
        hasNewerVersion: asBool(j['hasNewerVersion']),
        startDate: asDate(j['startDate']),
        frequencyDaysPerWeek: asInt(j['frequencyDaysPerWeek']) ?? 0,
        visibilityMode: PlanVisibilityMode.parse(j['visibilityMode']),
        hideExercises: asBool(j['hideExercises']),
        hideSetsReps: asBool(j['hideSetsReps']),
        hideFutureWorkouts: asBool(j['hideFutureWorkouts']),
        disableTraineeEditing: asBool(j['disableTraineeEditing']),
        isActive: asBool(j['isActive'], fallback: true),
      );
}

class PlanAssignmentList {
  const PlanAssignmentList({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<PlanAssignmentSummary> items;
  final int page;
  final int pageSize;
  final int totalCount;

  factory PlanAssignmentList.fromJson(Map<String, dynamic> j) => PlanAssignmentList(
        items: asList(j['items'], PlanAssignmentSummary.fromJson),
        page: asInt(j['page']) ?? 1,
        pageSize: asInt(j['pageSize']) ?? 10,
        totalCount: asInt(j['totalCount']) ?? 0,
      );
}

/// View model for the Plans tab: one active assignment joined with its plan's name/cadence.
/// The assignment list carries no plan name, so we merge it with `GET /workout-plans`.
class AssignedPlan {
  const AssignedPlan({required this.assignment, this.planName, this.workoutsPerWeek});

  final PlanAssignmentSummary assignment;
  final String? planName;
  final int? workoutsPerWeek;

  String get displayName => planName ?? 'Assigned plan';
  PlanVisibilityMode get visibility => assignment.visibilityMode;
  bool get isBlind => assignment.visibilityMode == PlanVisibilityMode.blind;
}
