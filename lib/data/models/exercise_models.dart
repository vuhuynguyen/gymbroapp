import '../../core/utils/json.dart';
import '../../domain/enums.dart';

/// `GET /api/exercises` → ExerciseDto[] (global catalog; used by the add/substitute picker).
class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.name,
    required this.type,
    this.trackingType = ExerciseTrackingType.strength,
    required this.movementType,
    required this.difficulty,
    required this.equipment,
    this.estimatedCaloriesBurn,
    this.averageDurationSeconds,
    required this.muscleGroup,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String type;

  /// Logging mode (Strength/Bodyweight/Cardio/Timed/Hiit/Mobility/Custom).
  final ExerciseTrackingType trackingType;
  final String movementType;
  final String difficulty;
  final String equipment;
  final int? estimatedCaloriesBurn;
  final int? averageDurationSeconds;
  final String muscleGroup;
  final String? imageUrl;

  factory ExerciseSummary.fromJson(Map<String, dynamic> j) => ExerciseSummary(
        id: j['id'].toString(),
        name: asString(j['name']) ?? '',
        type: asString(j['type']) ?? '',
        trackingType: ExerciseTrackingType.parse(j['trackingType']),
        movementType: asString(j['movementType']) ?? '',
        difficulty: asString(j['difficulty']) ?? '',
        equipment: asString(j['equipment']) ?? '',
        estimatedCaloriesBurn: asInt(j['estimatedCaloriesBurn']),
        averageDurationSeconds: asInt(j['averageDurationSeconds']),
        muscleGroup: asString(j['muscleGroup']) ?? '',
        imageUrl: asString(j['imageUrl']),
      );
}
