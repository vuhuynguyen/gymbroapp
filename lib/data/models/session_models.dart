import '../../core/utils/json.dart';
import '../../domain/enums.dart';

/// Mirrors `Modules.WorkoutSession.Application.DTOs` and the WebApi `Requests/Session`.
/// Field names track the camelCase JSON the API emits.

class PerformedSet {
  const PerformedSet({
    required this.id,
    this.planSetId,
    this.parentSetId,
    required this.setNumber,
    required this.setType,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceM,
    this.calories,
    this.avgHeartRate,
    this.rounds,
    this.rpe,
    this.restSeconds,
    required this.isCompleted,
    this.estimatedOneRepMaxKg,
    required this.loggedAt,
    required this.isPr,
  });

  final String id;
  final String? planSetId;

  /// Set when this row is a drop/rest-pause stage of the lead set [parentSetId] (counts as one logical set).
  final String? parentSetId;
  final int setNumber;
  final PerformedSetType setType;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final int? distanceM;
  final int? calories;
  final int? avgHeartRate;
  final int? rounds;
  final int? rpe;
  final int? restSeconds;
  final bool isCompleted;
  final double? estimatedOneRepMaxKg;
  final DateTime? loggedAt;
  final bool isPr;

  factory PerformedSet.fromJson(Map<String, dynamic> j) => PerformedSet(
        id: j['id'].toString(),
        planSetId: asString(j['planSetId']),
        parentSetId: asString(j['parentSetId']),
        setNumber: asInt(j['setNumber']) ?? 0,
        setType: PerformedSetType.parse(j['setType']),
        reps: asInt(j['reps']),
        weightKg: asDouble(j['weightKg']),
        durationSeconds: asInt(j['durationSeconds']),
        distanceM: asInt(j['distanceM']),
        calories: asInt(j['calories']),
        avgHeartRate: asInt(j['avgHeartRate']),
        rounds: asInt(j['rounds']),
        rpe: asInt(j['rpe']),
        restSeconds: asInt(j['restSeconds']),
        isCompleted: asBool(j['isCompleted'], fallback: true),
        estimatedOneRepMaxKg: asDouble(j['estimatedOneRepMaxKg']),
        loggedAt: asDate(j['loggedAt']),
        isPr: asBool(j['isPr']),
      );
}

/// The trainee's most recent PRIOR performance of a lift — the top working set of the last completed
/// session that included it. The live "last time" reference shown while logging; null when there's no
/// history. Computed server-side on read (see `LastPerformedSetDto`), never the current session.
class LastPerformed {
  const LastPerformed({this.weightKg, this.reps, this.performedAt});

  final double? weightKg;
  final int? reps;
  final DateTime? performedAt;

  factory LastPerformed.fromJson(Map<String, dynamic> j) => LastPerformed(
        weightKg: asDouble(j['weightKg']),
        reps: asInt(j['reps']),
        performedAt: asDate(j['performedAt']),
      );
}

class PerformedExercise {
  const PerformedExercise({
    required this.id,
    required this.exerciseId,
    this.exerciseName,
    this.planWorkoutExerciseId,
    this.substitutedFromExerciseId,
    this.substitutedFromExerciseName,
    required this.order,
    required this.status,
    this.notes,
    required this.sets,
    this.trackingType = ExerciseTrackingType.strength,
    this.supersetGroupId,
    this.lastPerformed,
  });

  final String id;
  final String exerciseId;
  final String? exerciseName;
  final String? planWorkoutExerciseId;
  final String? substitutedFromExerciseId;
  final String? substitutedFromExerciseName;
  final int order;
  final ExercisePerformStatus status;
  final String? notes;
  final List<PerformedSet> sets;

  /// Logging mode (denormalized at add/substitute time) — drives which metric inputs the logger shows.
  final ExerciseTrackingType trackingType;

  /// Exercises sharing a non-null group id are performed as a superset (rotated, rest after the round).
  final String? supersetGroupId;

  /// Most recent prior performance of this lift (last completed session), or null when there's no history.
  final LastPerformed? lastPerformed;

  /// Logged lead/standalone sets only — drop stages roll up into their lead, so a cluster counts as one set.
  int get leadSetCount => sets.where((s) => s.parentSetId == null).length;

  factory PerformedExercise.fromJson(Map<String, dynamic> j) =>
      PerformedExercise(
        id: j['id'].toString(),
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        planWorkoutExerciseId: asString(j['planWorkoutExerciseId']),
        substitutedFromExerciseId: asString(j['substitutedFromExerciseId']),
        substitutedFromExerciseName: asString(j['substitutedFromExerciseName']),
        order: asInt(j['order']) ?? 0,
        status: ExercisePerformStatus.parse(j['status']),
        notes: asString(j['notes']),
        sets: asList(j['sets'], PerformedSet.fromJson),
        trackingType: ExerciseTrackingType.parse(j['trackingType']),
        supersetGroupId: asString(j['supersetGroupId']),
        lastPerformed: j['lastPerformed'] is Map<String, dynamic>
            ? LastPerformed.fromJson(j['lastPerformed'] as Map<String, dynamic>)
            : null,
      );

  PerformedExercise copyWith(
          {List<PerformedSet>? sets, ExercisePerformStatus? status}) =>
      PerformedExercise(
        id: id,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        planWorkoutExerciseId: planWorkoutExerciseId,
        substitutedFromExerciseId: substitutedFromExerciseId,
        substitutedFromExerciseName: substitutedFromExerciseName,
        order: order,
        status: status ?? this.status,
        notes: notes,
        sets: sets ?? this.sets,
        trackingType: trackingType,
        supersetGroupId: supersetGroupId,
        lastPerformed: lastPerformed,
      );
}

/// Snapshot set: NOTE the API builds `setType` via `.ToString()`, so it arrives PascalCase
/// (`Working`). Parsed tolerantly into [PlanSetType].
class SessionSnapshotSet {
  const SessionSnapshotSet({
    required this.planSetId,
    required this.order,
    required this.setType,
    this.targetReps,
    this.targetWeightKg,
    this.targetRpe,
    this.targetDurationSeconds,
    this.targetDistanceM,
    this.targetRounds,
    required this.restSeconds,
  });

  final String planSetId;
  final int order;
  final PlanSetType setType;
  final int? targetReps;
  final double? targetWeightKg;
  final int? targetRpe;
  final int? targetDurationSeconds;
  final int? targetDistanceM;
  final int? targetRounds;
  final int restSeconds;

  factory SessionSnapshotSet.fromJson(Map<String, dynamic> j) =>
      SessionSnapshotSet(
        planSetId: j['planSetId'].toString(),
        order: asInt(j['order']) ?? 0,
        setType: PlanSetType.parse(j['setType']),
        targetReps: asInt(j['targetReps']),
        targetWeightKg: asDouble(j['targetWeightKg']),
        targetRpe: asInt(j['targetRpe']),
        targetDurationSeconds: asInt(j['targetDurationSeconds']),
        targetDistanceM: asInt(j['targetDistanceM']),
        targetRounds: asInt(j['targetRounds']),
        restSeconds: asInt(j['restSeconds']) ?? 0,
      );
}

class SessionSnapshotExercise {
  const SessionSnapshotExercise({
    required this.planWorkoutExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.order,
    required this.sets,
    this.supersetGroupId,
  });

  final String planWorkoutExerciseId;
  final String exerciseId;
  final String exerciseName;
  final int order;
  final List<SessionSnapshotSet> sets;
  final String? supersetGroupId;

  factory SessionSnapshotExercise.fromJson(Map<String, dynamic> j) =>
      SessionSnapshotExercise(
        planWorkoutExerciseId: j['planWorkoutExerciseId'].toString(),
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']) ?? '',
        order: asInt(j['order']) ?? 0,
        sets: asList(j['sets'], SessionSnapshotSet.fromJson),
        supersetGroupId: asString(j['supersetGroupId']),
      );
}

class SessionSnapshot {
  const SessionSnapshot({required this.workoutName, required this.exercises});

  final String workoutName;
  final List<SessionSnapshotExercise> exercises;

  factory SessionSnapshot.fromJson(Map<String, dynamic> j) => SessionSnapshot(
        workoutName: asString(j['workoutName']) ?? '',
        exercises: asList(j['exercises'], SessionSnapshotExercise.fromJson),
      );
}

/// `POST /api/sessions` response (also reused for the active session).
class SessionStartResult {
  const SessionStartResult({
    required this.sessionId,
    required this.status,
    required this.startedAt,
    required this.source,
    this.snapshot,
  });

  final String sessionId;
  final SessionStatus status;
  final DateTime? startedAt;
  final SessionSource source;
  final SessionSnapshot? snapshot;

  factory SessionStartResult.fromJson(Map<String, dynamic> j) =>
      SessionStartResult(
        sessionId: j['sessionId'].toString(),
        status: SessionStatus.parse(j['status'],
            fallback: SessionStatus.inProgress),
        startedAt: asDate(j['startedAt']),
        source: SessionSource.parse(j['source']),
        snapshot: j['snapshot'] == null
            ? null
            : SessionSnapshot.fromJson(j['snapshot'] as Map<String, dynamic>),
      );
}

/// `GET /api/sessions/active` (204 ⇒ null at the repository layer).
class ActiveSession {
  const ActiveSession({
    required this.sessionId,
    required this.status,
    required this.startedAt,
    required this.source,
    this.snapshot,
    required this.exercises,
  });

  final String sessionId;
  final SessionStatus status;
  final DateTime? startedAt;
  final SessionSource source;
  final SessionSnapshot? snapshot;
  final List<PerformedExercise> exercises;

  factory ActiveSession.fromJson(Map<String, dynamic> j) => ActiveSession(
        sessionId: j['sessionId'].toString(),
        status: SessionStatus.parse(j['status'],
            fallback: SessionStatus.inProgress),
        startedAt: asDate(j['startedAt']),
        source: SessionSource.parse(j['source']),
        snapshot: j['snapshot'] == null
            ? null
            : SessionSnapshot.fromJson(j['snapshot'] as Map<String, dynamic>),
        exercises: asList(j['exercises'], PerformedExercise.fromJson),
      );

  ActiveSession copyWith(
          {List<PerformedExercise>? exercises, SessionStatus? status}) =>
      ActiveSession(
        sessionId: sessionId,
        status: status ?? this.status,
        startedAt: startedAt,
        source: source,
        snapshot: snapshot,
        exercises: exercises ?? this.exercises,
      );

  /// Build an ActiveSession view from a (possibly historical) detail record — mirrors the
  /// Portal's `loadFromDetail` fallback when `/active` doesn't match the requested id.
  factory ActiveSession.fromDetail(SessionDetail d) => ActiveSession(
        sessionId: d.id,
        status: d.status,
        startedAt: d.startedAt,
        source: d.source,
        snapshot: d.snapshot ??
            (d.workoutNameSnapshot != null
                ? SessionSnapshot(
                    workoutName: d.workoutNameSnapshot!, exercises: const [])
                : null),
        exercises: d.exercises,
      );
}

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.traineeId,
    this.traineeName,
    required this.source,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds,
    required this.totalSets,
    required this.totalExercises,
    this.rpeOverall,
    this.planAssignmentId,
    this.workoutName,
    required this.totalVolumeKg,
    required this.prCount,
    this.programName,
    this.planWeek,
    this.weeklyGoal,
  });

  final String id;
  final String traineeId;
  final String? traineeName;
  final SessionSource source;
  final SessionStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final int totalSets;
  final int totalExercises;
  final int? rpeOverall;
  final String? planAssignmentId;
  final String? workoutName;
  final double totalVolumeKg;
  final int prCount;
  final String? programName;
  final int? planWeek;
  final int? weeklyGoal;

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        id: j['id'].toString(),
        traineeId: j['traineeId'].toString(),
        traineeName: asString(j['traineeName']),
        source: SessionSource.parse(j['source']),
        status: SessionStatus.parse(j['status']),
        startedAt: asDate(j['startedAt']),
        completedAt: asDate(j['completedAt']),
        durationSeconds: asInt(j['durationSeconds']),
        totalSets: asInt(j['totalSets']) ?? 0,
        totalExercises: asInt(j['totalExercises']) ?? 0,
        rpeOverall: asInt(j['rpeOverall']),
        planAssignmentId: asString(j['planAssignmentId']),
        workoutName: asString(j['workoutName']),
        totalVolumeKg: asDouble(j['totalVolumeKg']) ?? 0,
        prCount: asInt(j['prCount']) ?? 0,
        programName: asString(j['programName']),
        planWeek: asInt(j['planWeek']),
        weeklyGoal: asInt(j['weeklyGoal']),
      );
}

class SessionList {
  const SessionList({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<SessionSummary> items;
  final int page;
  final int pageSize;
  final int totalCount;

  factory SessionList.fromJson(Map<String, dynamic> j) => SessionList(
        items: asList(j['items'], SessionSummary.fromJson),
        page: asInt(j['page']) ?? 1,
        pageSize: asInt(j['pageSize']) ?? 20,
        totalCount: asInt(j['totalCount']) ?? 0,
      );
}

class SessionPr {
  const SessionPr({
    required this.exerciseId,
    this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.estimatedOneRepMaxKg,
    this.previousEstimatedOneRepMaxKg,
  });

  final String exerciseId;
  final String? exerciseName;
  final double weightKg;
  final int reps;
  final double estimatedOneRepMaxKg;
  final double? previousEstimatedOneRepMaxKg;

  factory SessionPr.fromJson(Map<String, dynamic> j) => SessionPr(
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        weightKg: asDouble(j['weightKg']) ?? 0,
        reps: asInt(j['reps']) ?? 0,
        estimatedOneRepMaxKg: asDouble(j['estimatedOneRepMaxKg']) ?? 0,
        previousEstimatedOneRepMaxKg:
            asDouble(j['previousEstimatedOneRepMaxKg']),
      );
}

class SessionDetail {
  const SessionDetail({
    required this.id,
    required this.traineeId,
    required this.source,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.rpeOverall,
    this.bodyweightKg,
    this.notes,
    this.clientTimezone,
    this.planAssignmentId,
    this.plannedWorkoutId,
    this.workoutNameSnapshot,
    required this.exercises,
    this.snapshot,
    required this.totalVolumeKg,
    this.programName,
    this.planWeek,
    required this.prs,
  });

  final String id;
  final String traineeId;
  final SessionSource source;
  final SessionStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final int? rpeOverall;
  final double? bodyweightKg;
  final String? notes;
  final String? clientTimezone;
  final String? planAssignmentId;
  final String? plannedWorkoutId;
  final String? workoutNameSnapshot;
  final List<PerformedExercise> exercises;
  final SessionSnapshot? snapshot;
  final double totalVolumeKg;
  final String? programName;
  final int? planWeek;
  final List<SessionPr> prs;

  factory SessionDetail.fromJson(Map<String, dynamic> j) => SessionDetail(
        id: j['id'].toString(),
        traineeId: j['traineeId'].toString(),
        source: SessionSource.parse(j['source']),
        status: SessionStatus.parse(j['status']),
        startedAt: asDate(j['startedAt']),
        completedAt: asDate(j['completedAt']),
        durationSeconds: asInt(j['durationSeconds']),
        rpeOverall: asInt(j['rpeOverall']),
        bodyweightKg: asDouble(j['bodyweightKg']),
        notes: asString(j['notes']),
        clientTimezone: asString(j['clientTimezone']),
        planAssignmentId: asString(j['planAssignmentId']),
        plannedWorkoutId: asString(j['plannedWorkoutId']),
        workoutNameSnapshot: asString(j['workoutNameSnapshot']),
        exercises: asList(j['exercises'], PerformedExercise.fromJson),
        snapshot: j['snapshot'] == null
            ? null
            : SessionSnapshot.fromJson(j['snapshot'] as Map<String, dynamic>),
        totalVolumeKg: asDouble(j['totalVolumeKg']) ?? 0,
        programName: asString(j['programName']),
        planWeek: asInt(j['planWeek']),
        prs: asList(j['prs'], SessionPr.fromJson),
      );
}

// ── Request bodies ────────────────────────────────────────────────────────

class StartSessionRequest {
  const StartSessionRequest({
    required this.source,
    this.planAssignmentId,
    this.plannedWorkoutId,
    this.clientTimezone,
    this.bodyweightKg,
  });

  final SessionSource source;
  final String? planAssignmentId;
  final String? plannedWorkoutId;
  final String? clientTimezone;
  final double? bodyweightKg;

  Map<String, dynamic> toJson() => {
        'source': source.wire,
        if (planAssignmentId != null) 'planAssignmentId': planAssignmentId,
        if (plannedWorkoutId != null) 'plannedWorkoutId': plannedWorkoutId,
        if (clientTimezone != null) 'clientTimezone': clientTimezone,
        if (bodyweightKg != null) 'bodyweightKg': bodyweightKg,
      };
}

class AddExerciseRequest {
  const AddExerciseRequest({
    required this.exerciseId,
    this.planWorkoutExerciseId,
    required this.order,
    this.notes,
  });

  final String exerciseId;
  final String? planWorkoutExerciseId;
  final int order;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        if (planWorkoutExerciseId != null)
          'planWorkoutExerciseId': planWorkoutExerciseId,
        'order': order,
        if (notes != null) 'notes': notes,
      };
}

class UpdateExerciseRequest {
  const UpdateExerciseRequest(
      {required this.action, this.substituteExerciseId, this.notes});

  final ExerciseUpdateAction action;
  final String? substituteExerciseId;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'action': action.wire,
        if (substituteExerciseId != null)
          'substituteExerciseId': substituteExerciseId,
        if (notes != null) 'notes': notes,
      };
}

class LogSetRequest {
  const LogSetRequest({
    this.planSetId,
    this.parentSetId,
    required this.setNumber,
    this.setType = PerformedSetType.working,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceM,
    this.calories,
    this.avgHeartRate,
    this.rounds,
    this.rpe,
    this.restSeconds,
    this.isCompleted = true,
  });

  final String? planSetId;

  /// Set when logging a drop/rest-pause stage of an existing lead set.
  final String? parentSetId;
  final int setNumber;
  final PerformedSetType setType;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final int? distanceM;
  final int? calories;
  final int? avgHeartRate;
  final int? rounds;
  final int? rpe;
  final int? restSeconds;
  final bool isCompleted;

  // The server validator enforces WeightKg > 0 and Reps >= 1 *when present*, so a bodyweight set
  // (weight 0) must OMIT weightKg rather than send 0.0 — otherwise the API 400s. Omit any
  // non-positive/null numeric field; only the always-required keys are sent unconditionally.
  Map<String, dynamic> toJson() => {
        if (planSetId != null) 'planSetId': planSetId,
        if (parentSetId != null) 'parentSetId': parentSetId,
        'setNumber': setNumber,
        'setType': setType.wire,
        if (reps != null && reps! >= 1) 'reps': reps,
        if (weightKg != null && weightKg! > 0) 'weightKg': weightKg,
        if (durationSeconds != null && durationSeconds! > 0)
          'durationSeconds': durationSeconds,
        if (distanceM != null && distanceM! > 0) 'distanceM': distanceM,
        if (calories != null && calories! > 0) 'calories': calories,
        if (avgHeartRate != null && avgHeartRate! > 0)
          'avgHeartRate': avgHeartRate,
        if (rounds != null && rounds! >= 1) 'rounds': rounds,
        if (rpe != null && rpe! > 0) 'rpe': rpe,
        if (restSeconds != null && restSeconds! > 0) 'restSeconds': restSeconds,
        'isCompleted': isCompleted,
      };
}

class EditSetRequest {
  const EditSetRequest({
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceM,
    this.rpe,
    this.restSeconds,
    this.isCompleted,
    this.setType,
  });

  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final int? distanceM;
  final int? rpe;
  final int? restSeconds;
  final bool? isCompleted;
  final PerformedSetType? setType;

  // Same positive-value rule as LogSetRequest; only send the fields actually being changed.
  Map<String, dynamic> toJson() => {
        if (reps != null && reps! >= 1) 'reps': reps,
        if (weightKg != null && weightKg! > 0) 'weightKg': weightKg,
        if (durationSeconds != null && durationSeconds! > 0)
          'durationSeconds': durationSeconds,
        if (distanceM != null && distanceM! > 0) 'distanceM': distanceM,
        if (rpe != null) 'rpe': rpe,
        if (restSeconds != null) 'restSeconds': restSeconds,
        if (isCompleted != null) 'isCompleted': isCompleted,
        if (setType != null) 'setType': setType!.wire,
      };
}

class CompleteSessionRequest {
  const CompleteSessionRequest({this.rpeOverall, this.notes, this.completedAt});

  final int? rpeOverall;
  final String? notes;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => {
        if (rpeOverall != null) 'rpeOverall': rpeOverall,
        if (notes != null) 'notes': notes,
        if (completedAt != null)
          'completedAt': completedAt!.toUtc().toIso8601String(),
      };
}
