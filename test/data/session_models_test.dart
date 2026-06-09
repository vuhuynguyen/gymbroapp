import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/session_models.dart';
import 'package:gymbroapp/domain/enums.dart';

void main() {
  test('ActiveSession.fromJson parses camelCase enums + PascalCase snapshot setType', () {
    final json = {
      'sessionId': 'sess-1',
      'status': 'inProgress', // camelCase from the API
      'startedAt': '2026-06-07T18:40:00Z',
      'source': 'fromAssignment',
      'snapshot': {
        'workoutName': 'Push Day',
        'exercises': [
          {
            'planWorkoutExerciseId': 'pwe-1',
            'exerciseId': 'ex-1',
            'exerciseName': 'Bench Press',
            'order': 1,
            'sets': [
              {
                'planSetId': 'ps-1',
                'order': 1,
                'setType': 'Working', // PascalCase — snapshot uses .ToString()
                'targetReps': 8,
                'targetWeightKg': 60.0,
                'targetRpe': 8,
                'targetDurationSeconds': null,
                'restSeconds': 120,
              },
            ],
          },
        ],
      },
      'exercises': [
        {
          'id': 'pe-1',
          'exerciseId': 'ex-1',
          'exerciseName': 'Bench Press',
          'order': 1,
          'status': 'inProgress',
          'sets': [
            {
              'id': 'set-1',
              'planSetId': 'ps-1',
              'setNumber': 1,
              'setType': 'working',
              'reps': 8,
              'weightKg': 62.5,
              'isCompleted': true,
              'estimatedOneRepMaxKg': 79.2,
              'loggedAt': '2026-06-07T18:45:00Z',
              'isPr': true,
            },
          ],
        },
      ],
    };

    final s = ActiveSession.fromJson(json);
    expect(s.sessionId, 'sess-1');
    expect(s.status, SessionStatus.inProgress);
    expect(s.source, SessionSource.fromAssignment);
    expect(s.snapshot!.workoutName, 'Push Day');
    expect(s.snapshot!.exercises.single.sets.single.setType, PlanSetType.working);
    expect(s.snapshot!.exercises.single.sets.single.targetWeightKg, 60.0);
    expect(s.exercises.single.sets.single.weightKg, 62.5);
    expect(s.exercises.single.sets.single.isPr, isTrue);
    expect(s.exercises.single.status, ExercisePerformStatus.inProgress);
  });

  test('SessionSummary.fromJson coerces decimal volume and missing optionals', () {
    final json = {
      'id': 'x',
      'traineeId': 't',
      'source': 'adhoc',
      'status': 'completed',
      'startedAt': '2026-06-07T10:00:00Z',
      'completedAt': '2026-06-07T11:00:00Z',
      'durationSeconds': 3600,
      'totalSets': 16,
      'totalExercises': 5,
      'totalVolumeKg': 10320, // integer JSON for a decimal field
      'prCount': 1,
    };
    final s = SessionSummary.fromJson(json);
    expect(s.status, SessionStatus.completed);
    expect(s.source, SessionSource.adhoc);
    expect(s.totalVolumeKg, 10320.0);
    expect(s.rpeOverall, isNull);
    expect(s.prCount, 1);
  });

  test('LogSetRequest omits non-positive weight/reps so the server accepts bodyweight sets', () {
    // Server validator: WeightKg > 0 / Reps >= 1 when present. A bodyweight set (weight 0) must
    // omit weightKg rather than send 0.0 (which 400s).
    final bodyweight = const LogSetRequest(setNumber: 1, reps: 10, weightKg: 0).toJson();
    expect(bodyweight.containsKey('weightKg'), isFalse);
    expect(bodyweight['reps'], 10);
    expect(bodyweight['setType'], 'working');
    expect(bodyweight['isCompleted'], true);

    final loaded = const LogSetRequest(setNumber: 2, reps: 8, weightKg: 60).toJson();
    expect(loaded['weightKg'], 60);
    expect(loaded['reps'], 8);
  });
}
