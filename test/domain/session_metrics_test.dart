import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/session_models.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:gymbroapp/domain/session_metrics.dart';

PerformedSet _set({
  int? reps,
  double? weightKg,
  int? rpe,
  bool completed = true,
}) =>
    PerformedSet(
      id: 's',
      setNumber: 1,
      setType: PerformedSetType.working,
      reps: reps,
      weightKg: weightKg,
      rpe: rpe,
      isCompleted: completed,
      loggedAt: null,
      isPr: false,
    );

PerformedExercise _ex(List<PerformedSet> sets) => PerformedExercise(
      id: 'e',
      exerciseId: 'x',
      order: 1,
      status: ExercisePerformStatus.inProgress,
      sets: sets,
    );

void main() {
  test('sumCompletedVolumeKg counts only completed sets', () {
    final ex = _ex([
      _set(reps: 10, weightKg: 60),
      _set(reps: 8, weightKg: 60),
      _set(reps: 8, weightKg: 60, completed: false), // excluded
    ]);
    expect(sumCompletedVolumeKg([ex]), 10 * 60 + 8 * 60);
  });

  test('averageCompletedRpe ignores null and incomplete', () {
    final ex = _ex([
      _set(reps: 5, rpe: 8),
      _set(reps: 5, rpe: 9),
      _set(reps: 5, rpe: 10, completed: false), // excluded
      _set(reps: 5), // no rpe
    ]);
    expect(averageCompletedRpe([ex]), 8.5);
  });

  test('computeProgressPercent clamps and handles zero total', () {
    expect(computeProgressPercent(0, 0), 0);
    expect(computeProgressPercent(2, 4), 50);
    expect(computeProgressPercent(5, 4), 100);
  });

  test('resolveTargetSetCount picks the max, with the active entry row', () {
    expect(resolveTargetSetCount(2, 4, false), 4); // planned dominates
    expect(resolveTargetSetCount(4, 3, true), 5); // logged + active row dominates
    expect(resolveTargetSetCount(0, 0, true), 1); // never below 1 when active
  });

  test('isPerformedExerciseComplete respects planned count', () {
    final ex = _ex([_set(), _set()]);
    expect(isPerformedExerciseComplete(ex, 3), isFalse);
    expect(isPerformedExerciseComplete(ex, 2), isTrue);
    expect(isPerformedExerciseComplete(_ex([]), 0), isFalse); // planned 0 never complete
  });

  test('epleyOneRepMax matches the server formula (Epley, 1dp)', () {
    expect(epleyOneRepMax(100, 5), 116.7); // 100 * (1 + 5/30) = 116.666..
    expect(epleyOneRepMax(0, 5), isNull);
    expect(epleyOneRepMax(60, 0), isNull);
  });

  test('formatDuration switches to H:MM:SS over an hour', () {
    expect(formatDuration(65), '01:05');
    expect(formatDuration(3661), '1:01:01');
  });
}
