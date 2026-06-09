import 'enums.dart';

/// Mobile mirror of the API's `ExerciseTrackingRules` — single source of truth for which set metrics a
/// tracking mode shows and requires. Keep in sync with the C#/Angular matrices.
enum TrackingMetric { reps, weight, duration, distance, rounds, rest, rpe, calories, heartRate }

class TrackingProfile {
  const TrackingProfile({
    required this.type,
    required this.fields,
    required this.primary,
    required this.allowCompletionOnly,
    this.extras = const [],
  });

  final ExerciseTrackingType type;

  /// Essential set-entry inputs shown by default (kept to 1–2 so the card stays clean).
  final List<TrackingMetric> fields;

  /// Secondary inputs (calories / heart rate / rest) revealed behind a "+ More" toggle.
  final List<TrackingMetric> extras;

  /// At least one must be present to log a set (empty = no metric required).
  final List<TrackingMetric> primary;

  /// A metric-less set marked completed is valid (mark-done).
  final bool allowCompletionOnly;
}

const _rest = TrackingMetric.rest;

const _profiles = <ExerciseTrackingType, TrackingProfile>{
  ExerciseTrackingType.strength: TrackingProfile(
    type: ExerciseTrackingType.strength,
    fields: [TrackingMetric.weight, TrackingMetric.reps],
    extras: [_rest],
    primary: [TrackingMetric.reps],
    allowCompletionOnly: false,
  ),
  ExerciseTrackingType.bodyweight: TrackingProfile(
    type: ExerciseTrackingType.bodyweight,
    fields: [TrackingMetric.reps, TrackingMetric.weight],
    extras: [_rest],
    primary: [TrackingMetric.reps],
    allowCompletionOnly: false,
  ),
  ExerciseTrackingType.cardio: TrackingProfile(
    type: ExerciseTrackingType.cardio,
    fields: [TrackingMetric.duration, TrackingMetric.distance],
    extras: [TrackingMetric.calories, TrackingMetric.heartRate, _rest],
    primary: [TrackingMetric.duration, TrackingMetric.distance],
    allowCompletionOnly: false,
  ),
  ExerciseTrackingType.timed: TrackingProfile(
    type: ExerciseTrackingType.timed,
    fields: [TrackingMetric.duration],
    extras: [_rest],
    primary: [TrackingMetric.duration],
    allowCompletionOnly: false,
  ),
  ExerciseTrackingType.hiit: TrackingProfile(
    type: ExerciseTrackingType.hiit,
    fields: [TrackingMetric.rounds, TrackingMetric.duration],
    extras: [TrackingMetric.calories, TrackingMetric.heartRate, _rest],
    primary: [TrackingMetric.rounds, TrackingMetric.duration],
    allowCompletionOnly: false,
  ),
  ExerciseTrackingType.mobility: TrackingProfile(
    type: ExerciseTrackingType.mobility,
    fields: [TrackingMetric.duration, TrackingMetric.reps],
    extras: [_rest],
    primary: [],
    allowCompletionOnly: true,
  ),
  ExerciseTrackingType.custom: TrackingProfile(
    type: ExerciseTrackingType.custom,
    fields: [TrackingMetric.reps, TrackingMetric.weight, TrackingMetric.duration, TrackingMetric.distance, TrackingMetric.rounds],
    extras: [TrackingMetric.calories, TrackingMetric.heartRate, _rest],
    primary: [TrackingMetric.reps, TrackingMetric.weight, TrackingMetric.duration, TrackingMetric.distance, TrackingMetric.rounds],
    allowCompletionOnly: true,
  ),
};

TrackingProfile trackingProfileFor(ExerciseTrackingType type) =>
    _profiles[type] ?? _profiles[ExerciseTrackingType.strength]!;

/// Metric values to test against a mode's primary-metric rule.
class SetMetricValues {
  const SetMetricValues({this.reps, this.weightKg, this.durationSeconds, this.distanceM, this.rounds, this.isCompleted = true});
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final int? distanceM;
  final int? rounds;
  final bool isCompleted;
}

/// True when the values carry at least the primary metric for the mode (mirrors the server rule).
bool hasRequiredMetric(ExerciseTrackingType type, SetMetricValues v) {
  final profile = trackingProfileFor(type);
  if (profile.allowCompletionOnly && v.isCompleted) return true;
  if (profile.primary.isEmpty) return true;

  final present = <TrackingMetric>{};
  if ((v.reps ?? 0) > 0) present.add(TrackingMetric.reps);
  if ((v.weightKg ?? 0) > 0) present.add(TrackingMetric.weight);
  if ((v.durationSeconds ?? 0) > 0) present.add(TrackingMetric.duration);
  if ((v.distanceM ?? 0) > 0) present.add(TrackingMetric.distance);
  if ((v.rounds ?? 0) > 0) present.add(TrackingMetric.rounds);

  return profile.primary.any(present.contains);
}

/// User-facing hint describing what a set of this mode needs (mirrors the server message).
String requiredMetricMessage(ExerciseTrackingType type) {
  switch (type) {
    case ExerciseTrackingType.strength:
    case ExerciseTrackingType.bodyweight:
      return 'Enter your reps to log the set.';
    case ExerciseTrackingType.cardio:
      return 'Enter a duration or distance to log the set.';
    case ExerciseTrackingType.timed:
      return 'Enter a duration to log the set.';
    case ExerciseTrackingType.hiit:
      return 'Enter rounds or a work duration to log the set.';
    case ExerciseTrackingType.mobility:
      return 'Mark the set completed or enter a duration.';
    case ExerciseTrackingType.custom:
      return 'Enter at least one metric to log the set.';
  }
}
