import '../../core/utils/json.dart';
import '../../domain/enums.dart';

/// `GET /api/exercises/{id}` — full exercise detail used by the Form Coach guide sheet.
class ExerciseDetail {
  const ExerciseDetail({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.equipment,
    required this.muscleGroup,
    required this.instructions,
    required this.muscles,
    required this.warnings,
    required this.media,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String difficulty;
  final String equipment;
  final String muscleGroup;

  /// Ordered execution steps from the API (`instructions` field).
  final List<String> instructions;

  /// Muscle targets — each entry has `name` and `isPrimary`.
  final List<ExerciseMuscle> muscles;

  /// Safety warnings / contraindications; shown in the Mistakes tab callout.
  final List<String> warnings;

  /// Media attachments (images / demo clips) from the API.
  final List<ExerciseMedia> media;

  final String? imageUrl;

  List<ExerciseMuscle> get primaryMuscles => muscles.where((m) => m.isPrimary).toList();
  List<ExerciseMuscle> get secondaryMuscles => muscles.where((m) => !m.isPrimary).toList();

  /// First image URL from the media list, falling back to the top-level imageUrl.
  String? get heroImageUrl {
    final img = media.where((m) => m.type == 'image').firstOrNull;
    return img?.url ?? imageUrl;
  }

  factory ExerciseDetail.fromJson(Map<String, dynamic> j) => ExerciseDetail(
        id: j['id'].toString(),
        name: asString(j['name']) ?? '',
        difficulty: asString(j['difficulty']) ?? '',
        equipment: asString(j['equipment']) ?? '',
        muscleGroup: asString(j['muscleGroup']) ?? '',
        instructions: (j['instructions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(growable: false),
        muscles: (j['muscles'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ExerciseMuscle.fromJson)
            .toList(growable: false),
        warnings: (j['warnings'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(growable: false),
        media: (j['media'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ExerciseMedia.fromJson)
            .toList(growable: false),
        imageUrl: asString(j['imageUrl']),
      );
}

class ExerciseMuscle {
  const ExerciseMuscle({required this.name, required this.isPrimary});
  final String name;
  final bool isPrimary;

  factory ExerciseMuscle.fromJson(Map<String, dynamic> j) => ExerciseMuscle(
        // C# DTO uses "muscle" (not "name") — see ExerciseMuscleItemDto.
        name: asString(j['muscle']) ?? asString(j['name']) ?? '',
        isPrimary: j['isPrimary'] == true,
      );
}

class ExerciseMedia {
  const ExerciseMedia({required this.url, required this.type});
  final String url;
  final String type;

  factory ExerciseMedia.fromJson(Map<String, dynamic> j) => ExerciseMedia(
        url: asString(j['url']) ?? '',
        type: (asString(j['type']) ?? 'image').toLowerCase(),
      );
}

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
    this.muscles = const [],
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

  /// Full targeted-muscle list (primary + secondary), primary-first. Empty on older payloads.
  final List<ExerciseMuscle> muscles;
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
        muscles: (j['muscles'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ExerciseMuscle.fromJson)
            .toList(growable: false),
        imageUrl: asString(j['imageUrl']),
      );
}
