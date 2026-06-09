// Pure, framework-free metric + formatting helpers — a faithful Dart port of the Portal's
// `session-metrics.ts`. Keep these pure (no Flutter imports) so they are trivially unit-testable
// and so the UI can be replaced without touching the math. The server is still the source of
// truth for stored metrics (volume, e1RM, PR count); these mirror its client-side derivations.
import '../data/models/session_models.dart';

String _fmtKg(double kg) => kg % 1 == 0 ? '${kg.toInt()}kg' : '${kg}kg';

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
  if ((set.durationSeconds ?? 0) > 0) parts.add(formatDuration(set.durationSeconds!));
  if ((set.distanceM ?? 0) > 0) parts.add('${set.distanceM}m');
  if ((set.rounds ?? 0) > 0) parts.add('${set.rounds} rounds');
  if ((set.calories ?? 0) > 0) parts.add('${set.calories}kcal');
  if ((set.avgHeartRate ?? 0) > 0) parts.add('${set.avgHeartRate}bpm');
  return parts.isEmpty ? '—' : parts.join(' · ');
}

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
int resolveTargetSetCount(int loggedCount, int plannedCount, bool includeActiveRow) {
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
  if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0) return null;
  return ((weightKg * (1 + reps / 30)) * 10).round() / 10;
}
