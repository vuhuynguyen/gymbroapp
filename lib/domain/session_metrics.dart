// Pure, framework-free metric + formatting helpers — a faithful Dart port of the Portal's
// `session-metrics.ts`. Keep these pure (no Flutter imports) so they are trivially unit-testable
// and so the UI can be replaced without touching the math. The server is still the source of
// truth for stored metrics (volume, e1RM, PR count); these mirror its client-side derivations.
import '../data/models/session_models.dart';
import 'enums.dart';

String _fmtKg(double kg) => kg % 1 == 0 ? '${kg.toInt()}kg' : '${kg}kg';
String _fmt1(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';

/// Mode-aware, zero-suppressing summary of a logged set used everywhere a set is shown
/// (live logger, session detail, history). Only metrics with a real (> 0) value appear, so a
/// cardio set reads "00:15 · 150m" — never "—kg × —" or "0kcal".
String formatLoggedSet(PerformedSet set) {
  final parts = <String>[];
  final w = set.weightKg ?? 0;
  final r = set.reps ?? 0;
  if (w > 0 && r > 0) {
    parts.add('${_fmtKg(w)} × $r');
  } else if (r > 0) {
    parts.add('$r reps');
  } else if (w > 0) {
    parts.add(_fmtKg(w));
  }
  if ((set.durationSeconds ?? 0) > 0)
    parts.add(formatDuration(set.durationSeconds!));
  if ((set.distanceM ?? 0) > 0) parts.add('${set.distanceM}m');
  if ((set.inclinePercent ?? 0) > 0) parts.add('${_fmt1(set.inclinePercent!)}%');
  if ((set.speedKph ?? 0) > 0) parts.add('${_fmt1(set.speedKph!)}km/h');
  if ((set.level ?? 0) > 0) parts.add('L${set.level}');
  if ((set.rounds ?? 0) > 0) parts.add('${set.rounds} rounds');
  if ((set.calories ?? 0) > 0) parts.add('${set.calories}kcal');
  if ((set.avgHeartRate ?? 0) > 0) parts.add('${set.avgHeartRate}bpm');
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// A logged set as a chip label that leads with its position and type, e.g. "1 · Warmup · 30kg × 12".
/// Used everywhere sets are shown as chips so the number/type are always visible, not just the result.
String performedSetChip(PerformedSet set, int number) =>
    '$number · ${set.setType.label} · ${formatLoggedSet(set)}';

/// Format elapsed seconds as `H:MM:SS`, or `MM:SS` when under an hour.
String formatDuration(int seconds) {
  final hrs = seconds ~/ 3600;
  final mins = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  final m = mins.toString().padLeft(2, '0');
  final s = secs.toString().padLeft(2, '0');
  return hrs > 0 ? '$hrs:$m:$s' : '$m:$s';
}

/// Format rest seconds as `M:SS` (minutes not zero-padded).
String formatRestClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Compact human duration for list rows / summary tiles (design `fmtDuration`):
/// `1h 5m` past an hour, `18m` for whole minutes, else `m:ss`. Distinct from [formatDuration]
/// (the running stopwatch), which always uses `mm:ss` / `h:mm:ss`.
String formatDurationCompact(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
  return s == 0 ? '${m}m' : '$m:${s.toString().padLeft(2, '0')}';
}

/// Elapsed whole seconds from wall-clock anchors (self-corrects after the app is backgrounded).
int computeElapsedSeconds(int startMs, int nowMs, int pausedOffsetMs) {
  final v = ((nowMs - startMs - pausedOffsetMs) / 1000).floor();
  return v < 0 ? 0 : v;
}

int countLoggedSets(List<PerformedExercise> exercises) =>
    exercises.fold(0, (sum, ex) => sum + ex.sets.length);

/// Working-set volume (Σ weight × reps) over *completed* sets only, in kg.
double sumCompletedVolumeKg(List<PerformedExercise> exercises) {
  var total = 0.0;
  for (final ex in exercises) {
    for (final set in ex.sets) {
      if (!set.isCompleted) continue;
      total += (set.weightKg ?? 0) * (set.reps ?? 0);
    }
  }
  return total;
}

/// Mean RPE over completed sets that carry an RPE, rounded to 1 dp; null when none.
double? averageCompletedRpe(List<PerformedExercise> exercises) {
  final rpes = <int>[];
  for (final ex in exercises) {
    for (final set in ex.sets) {
      if (set.isCompleted && set.rpe != null) rpes.add(set.rpe!);
    }
  }
  if (rpes.isEmpty) return null;
  final avg = rpes.reduce((a, b) => a + b) / rpes.length;
  return (avg * 10).round() / 10;
}

/// Effective set count: the highest of planned, logged (+ the in-progress row when active), and 1.
int resolveTargetSetCount(
    int loggedCount, int plannedCount, bool includeActiveRow) {
  if (includeActiveRow) {
    return [plannedCount, loggedCount + 1, 1].reduce((a, b) => a > b ? a : b);
  }
  return plannedCount > loggedCount ? plannedCount : loggedCount;
}

/// An exercise is complete once completed-set count reaches the planned count.
/// With no plan (`plannedCount == null`) the logged-set count is the bar; planned 0 is never complete.
bool isPerformedExerciseComplete(PerformedExercise ex, int? plannedCount) {
  final planned = plannedCount ?? ex.sets.length;
  if (planned == 0) return false;
  return ex.sets.where((s) => s.isCompleted).length >= planned;
}

/// Logged/total as a clamped 0–100 integer percentage; 0 when there is no total.
int computeProgressPercent(int logged, int total) {
  if (total <= 0) return 0;
  final p = (logged / total * 100).round();
  return p > 100 ? 100 : p;
}

/// Epley estimated 1RM for display parity (`weight × (1 + reps/30)`, 1 dp). The server stores its
/// own value on each set; prefer that. Returns null unless reps and weight are both positive.
double? epleyOneRepMax(double? weightKg, int? reps) {
  if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0)
    return null;
  return ((weightKg * (1 + reps / 30)) * 10).round() / 10;
}

// ── Session-summary aggregates (post-workout review) ─────────────────────────
// All pure; counts treat a drop/rest-pause cluster as ONE set (lead = parentSetId == null) to match
// how the app rolls sets up, and exclude warmups from "working" (hard) sets.

/// Hard working sets — the hypertrophy signal: lead sets (no drop-stage double-count) that aren't warmups.
int workingSetCount(List<PerformedExercise> exercises) => exercises.fold(
    0,
    (a, e) =>
        a +
        e.sets
            .where((s) =>
                s.parentSetId == null && s.setType != PerformedSetType.warmup)
            .length);

/// Warmup sets logged across the session.
int warmupSetCount(List<PerformedExercise> exercises) => exercises.fold(
    0,
    (a, e) =>
        a + e.sets.where((s) => s.setType == PerformedSetType.warmup).length);

/// Total reps performed (every set that carried reps).
int totalReps(List<PerformedExercise> exercises) => exercises.fold(
    0, (a, e) => a + e.sets.fold<int>(0, (b, s) => b + (s.reps ?? 0)));

/// Mean logged rest (seconds) across sets that recorded one; null when none did.
int? averageRestSeconds(List<PerformedExercise> exercises) {
  final rests = <int>[
    for (final e in exercises)
      for (final s in e.sets)
        if ((s.restSeconds ?? 0) > 0) s.restSeconds!,
  ];
  if (rests.isEmpty) return null;
  return (rests.reduce((a, b) => a + b) / rests.length).round();
}

/// Work density — volume per training minute (kg/min); null when duration/volume is missing.
double? densityKgPerMin(double volumeKg, int? durationSeconds) {
  if (durationSeconds == null || durationSeconds <= 0 || volumeKg <= 0) {
    return null;
  }
  return volumeKg / (durationSeconds / 60);
}

/// Session training load (Foster's sRPE): session RPE × minutes — a simple, validated internal-load
/// number for tracking fatigue. Null unless both RPE and duration are present.
int? sessionLoad(int? rpeOverall, int? durationSeconds) {
  if (rpeOverall == null ||
      rpeOverall <= 0 ||
      durationSeconds == null ||
      durationSeconds <= 0) {
    return null;
  }
  return (rpeOverall * (durationSeconds / 60)).round();
}

/// True when the session is conditioning-only (no strength/bodyweight lifting) → drives the cardio
/// summary instead of the volume/sets one.
bool isCardioSession(List<PerformedExercise> exercises) =>
    exercises.isNotEmpty &&
    !exercises.any((e) =>
        e.trackingType == ExerciseTrackingType.strength ||
        e.trackingType == ExerciseTrackingType.bodyweight);

/// Working sets per primary muscle group, resolved via [muscleOf] (exerciseId → group label), sorted
/// desc by count. Exercises with no resolved muscle are skipped (never fabricate a group).
Map<String, int> workingSetsByMuscle(
  List<PerformedExercise> exercises,
  String? Function(String exerciseId) muscleOf,
) {
  final out = <String, int>{};
  for (final e in exercises) {
    final mg = muscleOf(e.exerciseId);
    if (mg == null || mg.isEmpty) continue;
    final n = e.sets
        .where((s) =>
            s.parentSetId == null && s.setType != PerformedSetType.warmup)
        .length;
    if (n == 0) continue;
    out[mg] = (out[mg] ?? 0) + n;
  }
  final sorted = out.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in sorted) e.key: e.value};
}

/// Conditioning totals (distance m, duration s, calories, mean HR) for the cardio summary.
({int distanceM, int durationSeconds, int calories, int? avgHeartRate})
    cardioTotals(List<PerformedExercise> exercises) {
  var dist = 0, dur = 0, cal = 0;
  final hrs = <int>[];
  for (final e in exercises) {
    for (final s in e.sets) {
      dist += s.distanceM ?? 0;
      dur += s.durationSeconds ?? 0;
      cal += s.calories ?? 0;
      if ((s.avgHeartRate ?? 0) > 0) hrs.add(s.avgHeartRate!);
    }
  }
  final hr =
      hrs.isEmpty ? null : (hrs.reduce((a, b) => a + b) / hrs.length).round();
  return (
    distanceM: dist,
    durationSeconds: dur,
    calories: cal,
    avgHeartRate: hr
  );
}
