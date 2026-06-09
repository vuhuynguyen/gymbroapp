import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/session_models.dart';
import 'package:gymbroapp/domain/enums.dart';

PerformedSet _set({required String id, String? parentSetId}) => PerformedSet(
      id: id,
      parentSetId: parentSetId,
      setNumber: 1,
      setType: PerformedSetType.working,
      isCompleted: true,
      loggedAt: null,
      isPr: false,
    );

void main() {
  test('leadSetCount rolls up drop stages — a cluster counts as one set', () {
    final ex = PerformedExercise(
      id: 'e1',
      exerciseId: 'x1',
      order: 1,
      status: ExercisePerformStatus.inProgress,
      sets: [
        _set(id: 'lead'),
        _set(id: 's1', parentSetId: 'lead'),
        _set(id: 's2', parentSetId: 'lead'),
        _set(id: 'standalone'),
      ],
    );
    // 4 rows, but the drop cluster + the standalone = 2 logical sets.
    expect(ex.sets.length, 4);
    expect(ex.leadSetCount, 2);
  });

  test('LogSetRequest serializes parentSetId only when set', () {
    final drop = const LogSetRequest(parentSetId: 'lead', setNumber: 2, reps: 4).toJson();
    expect(drop['parentSetId'], 'lead');
    final lead = const LogSetRequest(setNumber: 1, reps: 6).toJson();
    expect(lead.containsKey('parentSetId'), isFalse);
  });
}
