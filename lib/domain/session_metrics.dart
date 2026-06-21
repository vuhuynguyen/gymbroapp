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
  if ((set.inclinePercent ?? 0) > 0)
    parts.add('${_fmt1(set.inclinePercent!)}%');
  if ((set.speedKph ?? 0) > 0) parts.add('${_fmt1(set.speedKph!)}km/h');
  if ((set.level ?? 0) > 0) parts.add('L${set.level}');
  if ((set.rounds ?? 0) > 0) parts.add('${set.rounds} rounds');
  if ((set.calories ?? 0) > 0) parts.add('${set.calories}kcal');
  if ((set.avgHeartRate ?? 0) > 0) parts.add('${set.avgHeartRate}bpm');
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// A logged set as a chip label that leads with its position and type, e.g. "1 · Warmup · 30kg × 12".
/// Used everywhere sets are shown as chips so the number/type are always visible, not just the result.
/// The stored RPE (1-10 effort) is appended when logged — "1 · Working · 30kg × 12 · RPE 8" — so the
/// Session Detail breakdown shows how hard each set felt; an absent/zero RPE is simply omitted (never
/// fabricated, matching [formatLoggedSet]'s zero-suppression).
String performedSetChip(PerformedSet set, int number) {
  final base = '$number · ${set.setType.label} · ${formatLoggedSet(set)}';
  final rpe = set.rpe ?? 0;
  return rpe > 0 ? '$base · RPE $rpe' : base;
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

/// e1RM of an ACTUAL logged set, corrected for effort via the standard reps-in-reserve relationship
/// (RIR = 10 − RPE; Zourdos et al. 2016, NSCA Strength & Conditioning Journal): a set of `reps` at RPE
/// `rpe` stops `(10 − rpe)` reps short of failure, so it behaves like a max set of `reps + (10 − rpe)`,
/// fed into the same Epley model the app already uses for e1RM. So an easy 12 @ RPE 7 implies a higher
/// max than a grinding 12 @ RPE 10 at the same load. Falls back to plain Epley (assumes max effort) when
/// RPE wasn't logged, biasing the estimate *down* — the safe direction. Null unless reps & weight > 0.
double? effortAdjustedOneRepMax(double? weightKg, int? reps, int? rpe) {
  if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0)
    return null;
  final rir = rpe == null ? 0 : (10 - rpe).clamp(0, 10);
  return ((weightKg * (1 + (reps + rir) / 30)) * 10).round() / 10;
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

/// One muscle group's involvement this session: working sets where it was the primary mover vs a
/// secondary (assisting) mover.
class MuscleInvolvement {
  const MuscleInvolvement({required this.primary, required this.secondary});
  final int primary;
  final int secondary;
  int get total => primary + secondary;
}

/// Working sets per muscle group, split into primary vs secondary involvement, resolved via [musclesOf]
/// (exerciseId → that exercise's muscles, each a (group, isPrimary) pair). Sorted desc by total;
/// groups with no working sets are omitted. Never fabricated — an exercise with no resolved muscles is
/// skipped. A working set credits each of the exercise's muscles once (full credit to the primary
/// mover, indirect credit to the assisting muscles).
Map<String, MuscleInvolvement> muscleInvolvement(
  List<PerformedExercise> exercises,
  List<({String group, bool isPrimary})> Function(String exerciseId) musclesOf,
) {
  final prim = <String, int>{};
  final sec = <String, int>{};
  for (final e in exercises) {
    final sets = e.sets
        .where((s) =>
            s.parentSetId == null && s.setType != PerformedSetType.warmup)
        .length;
    if (sets == 0) continue;
    for (final m in musclesOf(e.exerciseId)) {
      if (m.group.isEmpty) continue;
      if (m.isPrimary) {
        prim[m.group] = (prim[m.group] ?? 0) + sets;
      } else {
        sec[m.group] = (sec[m.group] ?? 0) + sets;
      }
    }
  }
  final groups = {...prim.keys, ...sec.keys};
  final out = {
    for (final g in groups)
      g: MuscleInvolvement(primary: prim[g] ?? 0, secondary: sec[g] ?? 0)
  };
  final sorted = out.entries.toList()
    ..sort((a, b) => b.value.total.compareTo(a.value.total));
  return {for (final e in sorted) e.key: e.value};
}

/// One exercise's contribution to a muscle group: its working-set count and whether the group was a
/// primary or secondary mover for that exercise.
class MuscleExerciseContribution {
  const MuscleExerciseContribution({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.isPrimary,
  });
  final String exerciseId;
  final String name;
  final int sets;
  final bool isPrimary;
}

/// Per-muscle-group breakdown of WHICH exercises drove the working sets behind [muscleInvolvement] — so
/// the UI can answer "Back = 10 primary + 8 secondary, but from which lifts?". For each group, the
/// contributing exercises (working-set count + primary/secondary role), primary movers first then by
/// sets desc. [nameOf] resolves an exercise's display name. Warmups + drop stages are excluded exactly
/// like [muscleInvolvement], so each exercise's sets sum back to the group's primary/secondary totals.
Map<String, List<MuscleExerciseContribution>> muscleExerciseBreakdown(
  List<PerformedExercise> exercises,
  List<({String group, bool isPrimary})> Function(String exerciseId) musclesOf,
  String Function(PerformedExercise) nameOf,
) {
  final out = <String, List<MuscleExerciseContribution>>{};
  for (final e in exercises) {
    final sets = e.sets
        .where((s) =>
            s.parentSetId == null && s.setType != PerformedSetType.warmup)
        .length;
    if (sets == 0) continue;
    for (final m in musclesOf(e.exerciseId)) {
      if (m.group.isEmpty) continue;
      (out[m.group] ??= []).add(MuscleExerciseContribution(
        exerciseId: e.exerciseId,
        name: nameOf(e),
        sets: sets,
        isPrimary: m.isPrimary,
      ));
    }
  }
  for (final list in out.values) {
    list.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return b.sets.compareTo(a.sets);
    });
  }
  return out;
}

/// One lift's progress vs last time: this session's best working-set e1RM minus the previous session's
/// top-set e1RM (from `lastPerformed`). Null when there's no prior reference or nothing comparable.
class LiftProgress {
  const LiftProgress({
    required this.deltaE1rmKg,
    required this.lastWeightKg,
    required this.lastReps,
  });
  final double deltaE1rmKg;
  final double? lastWeightKg;
  final int? lastReps;
  // 0.5kg dead-band so rounding noise doesn't read as a change.
  bool get isUp => deltaE1rmKg > 0.5;
  bool get isDown => deltaE1rmKg < -0.5;
  bool get isSame => !isUp && !isDown;
}

/// Progress for one exercise vs its `lastPerformed` top set; null when no prior reference / no e1RM.
LiftProgress? liftProgress(PerformedExercise ex) {
  final last = ex.lastPerformed;
  if (last == null) return null;
  final lastE = epleyOneRepMax(last.weightKg, last.reps);
  if (lastE == null) return null;
  double? best;
  for (final s in ex.sets) {
    if (s.setType == PerformedSetType.warmup) continue;
    final e = s.estimatedOneRepMaxKg ?? epleyOneRepMax(s.weightKg, s.reps);
    if (e != null && (best == null || e > best)) best = e;
  }
  if (best == null) return null;
  return LiftProgress(
      deltaE1rmKg: best - lastE,
      lastWeightKg: last.weightKg,
      lastReps: last.reps);
}

/// Session roll-up of [liftProgress] across the exercises with a prior reference.
({int up, int down, int same, int compared}) sessionProgress(
    List<PerformedExercise> exercises) {
  var up = 0, down = 0, same = 0;
  for (final e in exercises) {
    final p = liftProgress(e);
    if (p == null) continue;
    if (p.isUp) {
      up++;
    } else if (p.isDown) {
      down++;
    } else {
      same++;
    }
  }
  return (up: up, down: down, same: same, compared: up + down + same);
}

// ── Suggested next set (pre-log "use this weight × reps") ─────────────────────
// Surfaces a starting weight × reps BEFORE the user logs, so they can accept ("Use") or fine-tune it.
// Layered, honest, and never auto-logged: plan target → last-time + small progression → RPE
// autoregulation, all from recognized standards. Pure (no Flutter, no I/O) so it's unit-testable.

/// A suggested next set surfaced *before* logging — a starting weight × reps the user can accept ("Use")
/// or adjust with the steppers. Strength/bodyweight only (where weight × reps is meaningful); null for
/// cardio/timed/etc. [reason] is a short, honest basis ("Plan target", "Last time + 2.5kg", "RPE 8")
/// so the user can judge the number rather than trust a black box.
class SetSuggestion {
  const SetSuggestion(
      {required this.weightKg, required this.reps, required this.reason});
  final double weightKg;
  final int reps;
  final String reason;
}

/// Round a working weight to the nearest [step] kg (2.5 = the plate / stepper increment).
double roundToStep(double kg, {double step = 2.5}) =>
    (kg / step).round() * step;

/// Suggest the next set's weight × reps from recognized strength-training standards (not bespoke math):
/// Epley e1RM (the model the logger already labels "Est. 1RM · Epley"), the reps-in-reserve / RPE scale
/// (RIR = 10 − RPE; Zourdos et al. 2016, NSCA S&C Journal), classic double progression, and the standard
/// accessory-load ranges (warm-up ~40–60%, drop set ~10–30%/≈20%). The engine is **closed-loop**: it
/// reads [performedSets] — the sets already logged for THIS exercise THIS session — so the number tracks
/// today's readiness and accumulated fatigue, not just a stale last-session reference. Priority:
///   1. plan prescribes an explicit weight → trust the coach's number (any set type).
///   2. accessory set → derive from the working weight, never a standalone heavy number:
///      warmup ≈ 50% of working; drop ≈ 20% below the set it follows (chained drops step down again).
///   3. plan prescribes reps + RPE but no weight → RIR-based autoregulation: treat `r` reps @ RPE `e`
///      as an `r + (10 − e)`-rep max and read the load off the e1RM anchor. The anchor is the most
///      recent in-session working set (effort-adjusted) when one exists, else the last-session top set
///      — so a hard/missed set today pulls the next suggestion DOWN.
///   4. no plan but a working set already done today → maintain the load and progress reps off the last
///      set's actual RPE (room left → +1 rep; already hard → ease a rep).
///   5. no plan, no in-session work → repeat last session with a small double-progression bump.
/// Returns null when there's nothing honest to anchor on (cardio/timed mode, or a brand-new lift with no
/// plan and no history). The UI renders it as a tappable chip; "Use" just prefills the steppers.
SetSuggestion? suggestNextSet({
  required ExerciseTrackingType trackingType,
  required PerformedSetType setType,
  SessionSnapshotSet? target,
  LastPerformed? lastPerformed,
  List<PerformedSet> performedSets = const [],
}) {
  // Weight × reps only makes sense for lifting; conditioning/timed/mobility modes get no weight suggestion.
  if (trackingType != ExerciseTrackingType.strength &&
      trackingType != ExerciseTrackingType.bodyweight) {
    return null;
  }

  // --- Today's reality (this session, this exercise). ---
  // Working sets logged so far, in order; the most recent is the live read of current capacity+fatigue.
  final todayWorking = performedSets
      .where((s) =>
          s.setType == PerformedSetType.working &&
          (s.weightKg ?? 0) > 0 &&
          (s.reps ?? 0) > 0)
      .toList();
  final lastTodayWorking = todayWorking.isEmpty ? null : todayWorking.last;
  final lastTodaySet = performedSets.isEmpty ? null : performedSets.last;
  // Effort-adjusted e1RM of the most recent working set (tracks today's trajectory); fall back to the
  // last completed session's top set when nothing's been logged yet.
  final todayAnchorE1rm = effortAdjustedOneRepMax(lastTodayWorking?.weightKg,
      lastTodayWorking?.reps, lastTodayWorking?.rpe);
  final priorE1rm =
      epleyOneRepMax(lastPerformed?.weightKg, lastPerformed?.reps);
  final anchorE1rm = todayAnchorE1rm ?? priorE1rm;

  final planW = target?.targetWeightKg ?? 0;
  final planR = target?.targetReps ?? 0;
  final planRpe = target?.targetRpe ?? 0;
  final lastW = lastPerformed?.weightKg ?? 0;
  final lastR = lastPerformed?.reps ?? 0;
  // The working load to scale an accessory (warmup/drop) off: today's last working set first.
  final workingAnchorW =
      lastTodayWorking?.weightKg ?? (planW > 0 ? planW : lastW);

  double? weight;
  int? reps;
  String reason;

  if (planW > 0 && planR > 0) {
    // 1. Explicit plan prescription — trust the coach for any set type.
    weight = planW;
    reps = planR;
    reason = 'Plan target';
  } else if (setType == PerformedSetType.warmup) {
    // 2a. Warmup set ≈ 50% of the working load — a general warm-up set sits in the standard ~40–60% range.
    if (workingAnchorW <= 0) return null;
    weight = roundToStep(workingAnchorW * 0.5);
    reps = planR > 0 ? planR : (lastTodayWorking?.reps ?? 10);
    reason = 'Warmup ~50%';
  } else if (setType == PerformedSetType.drop) {
    // 2b. Drop set ≈ 20% below the set it follows. The evidence-based reduction is ~10–30% per drop,
    // with ~20% the common recommendation (drop-set hypertrophy reviews; NASM/Sci-Fit guidelines). A
    // chained drop steps down again from the previous drop, else from the working weight — never the
    // last-session working number verbatim.
    final dropFrom = (lastTodaySet?.setType == PerformedSetType.drop &&
            (lastTodaySet?.weightKg ?? 0) > 0)
        ? lastTodaySet!.weightKg!
        : workingAnchorW;
    if (dropFrom <= 0) return null;
    weight = roundToStep(dropFrom * 0.80);
    reps = planR > 0
        ? planR
        : (lastTodaySet?.reps ?? lastTodayWorking?.reps ?? 10);
    reason = 'Drop ~20% lighter';
  } else if (planR > 0 && planRpe > 0 && anchorE1rm != null) {
    // 3. RIR-based RPE autoregulation — the standard method (Zourdos et al. 2016, NSCA Strength &
    // Conditioning Journal): RIR = 10 − RPE, so prescribing `planR` reps at `planRpe` means stopping
    // (10 − planRpe) reps short of failure → treat it as an `equivReps`-rep max and read the load off
    // the e1RM with Epley (the same model the logger shows as "Est. 1RM · Epley"). Anchored on today's
    // most-recent working set so the load tracks current readiness rather than a stale reference.
    reps = planR;
    final equivReps = planR + (10 - planRpe);
    weight = roundToStep(anchorE1rm / (1 + equivReps / 30));
    reason = todayAnchorE1rm != null
        ? 'RPE $planRpe · this session'
        : 'RPE $planRpe target';
  } else if (lastTodayWorking != null) {
    // 4. No plan, but already lifting today → hold the load, autoregulate reps off the last set's RPE.
    weight = lastTodayWorking.weightKg!;
    final lastSetRpe = lastTodayWorking.rpe;
    final lastSetReps = lastTodayWorking.reps!;
    if (lastSetRpe != null && lastSetRpe <= 7) {
      reps = lastSetReps + 1;
      reason = 'Maintain · room to push';
    } else if (lastSetRpe != null && lastSetRpe >= 9) {
      reps = (lastSetReps - 1).clamp(1, 99);
      reason = 'Maintain · ease a rep';
    } else {
      reps = lastSetReps;
      reason = 'Maintain';
    }
  } else if (lastW > 0 && lastR > 0) {
    // 5. First working set today, no plan → standard double progression off last session: at the top of
    // the rep range take the smallest plate jump (+2.5kg) and reset reps; below it, add a rep first.
    if (setType == PerformedSetType.working && lastR >= 12) {
      weight = roundToStep(lastW + 2.5);
      reps = (lastR - 2).clamp(1, 99);
      reason = 'Last time + 2.5kg';
    } else if (setType == PerformedSetType.working) {
      weight = lastW;
      reps = lastR + 1;
      reason = 'Last time + 1 rep';
    } else {
      weight = lastW;
      reps = lastR;
      reason = 'Last time';
    }
  } else {
    return null; // no plan, no history → nothing honest to suggest
  }

  if (weight <= 0 || reps <= 0) return null;
  return SetSuggestion(weightKg: weight, reps: reps, reason: reason);
}
