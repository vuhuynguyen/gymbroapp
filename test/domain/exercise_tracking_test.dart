import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:gymbroapp/domain/exercise_tracking.dart';

void main() {
  group('mode-aware required-metric rule (mirrors the server)', () {
    test('strength needs reps; weight alone is not enough', () {
      expect(hasRequiredMetric(ExerciseTrackingType.strength, const SetMetricValues(reps: 5)), isTrue);
      expect(hasRequiredMetric(ExerciseTrackingType.strength, const SetMetricValues(weightKg: 100)), isFalse);
    });

    test('cardio accepts duration or distance, not reps', () {
      expect(hasRequiredMetric(ExerciseTrackingType.cardio, const SetMetricValues(durationSeconds: 600)), isTrue);
      expect(hasRequiredMetric(ExerciseTrackingType.cardio, const SetMetricValues(distanceM: 2000)), isTrue);
      expect(hasRequiredMetric(ExerciseTrackingType.cardio, const SetMetricValues(reps: 10)), isFalse);
    });

    test('hiit accepts rounds or duration', () {
      expect(hasRequiredMetric(ExerciseTrackingType.hiit, const SetMetricValues(rounds: 5)), isTrue);
      expect(hasRequiredMetric(ExerciseTrackingType.hiit, const SetMetricValues(durationSeconds: 30)), isTrue);
    });

    test('mobility allows a completion-only set', () {
      expect(hasRequiredMetric(ExerciseTrackingType.mobility, const SetMetricValues(isCompleted: true)), isTrue);
    });

    test('tracking type parses tolerantly (camelCase / int / fallback)', () {
      expect(ExerciseTrackingType.parse('cardio'), ExerciseTrackingType.cardio);
      expect(ExerciseTrackingType.parse(5), ExerciseTrackingType.hiit);
      expect(ExerciseTrackingType.parse('nonsense'), ExerciseTrackingType.strength);
    });
  });
}
