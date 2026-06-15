import '../../core/utils/json.dart';

/// Hand-written DTOs for `GET /api/me/progress/overview` — the single self-scoped read that
/// powers the trainee Progress home (see gymbro/docs/progress/API-CONTRACTS.md §1). Field names
/// track the camelCase JSON the API emits; all parsing is defensive via `core/utils/json.dart`
/// coercers (the server returns `decimal` as a JSON number and dates as ISO-8601 / `yyyy-MM-dd`
/// strings, and is occasionally loose about int-vs-number).

/// Per-lift e1RM trend direction. Serialized as a camelCase string on the wire (`up`/`flat`/`down`),
/// parsed case/whitespace-tolerantly; `down` is the only state the UI is allowed to render red, and
/// only at the lift level — never page-wide (PHASE-1 §5).
enum LiftTrendDirection {
  up,
  flat,
  down;

  /// Tolerant parse: accepts the camelCase wire strings, ignores case/whitespace, and falls back to
  /// [flat] for anything unrecognized/null so a stray payload never throws.
  static LiftTrendDirection parse(Object? v) {
    final s = v?.toString().trim().toLowerCase();
    switch (s) {
      case 'up':
        return LiftTrendDirection.up;
      case 'down':
        return LiftTrendDirection.down;
      case 'flat':
      default:
        return LiftTrendDirection.flat;
    }
  }
}

/// Section 1 adherence — completed sessions vs the authoritative weekly goal, Monday-anchored in the
/// trainee's zone. `goal`/`hasActivePlan` drive the no-plan state (hide the ring, show raw count).
class WeekAdherence {
  const WeekAdherence({
    this.weekStart,
    required this.completedSessions,
    this.goal,
    required this.hasActivePlan,
  });

  /// Monday of the current week (local day). Null only on a malformed payload.
  final DateTime? weekStart;

  /// `Status == Completed` sessions this week (never abandoned/in-progress).
  final int completedSessions;

  /// Authoritative `FrequencyDaysPerWeek`; null when there's no active plan.
  final int? goal;
  final bool hasActivePlan;

  /// Ring fraction 0..1 — only meaningful when [hasActivePlan] with a positive [goal].
  double get ringValue {
    final g = goal;
    if (!hasActivePlan || g == null || g <= 0) return 0;
    return (completedSessions / g).clamp(0.0, 1.0);
  }

  factory WeekAdherence.fromJson(Map<String, dynamic> j) => WeekAdherence(
        weekStart: asDate(j['weekStart']),
        completedSessions: asInt(j['completedSessions']) ?? 0,
        goal: asInt(j['goal']),
        hasActivePlan: asBool(j['hasActivePlan']),
      );
}

/// One local day with at least one completed session — the heatmap fills the gaps (PHASE-1 §5).
class ConsistencyDay {
  const ConsistencyDay({required this.date, required this.sessionCount});

  final DateTime? date;
  final int sessionCount;

  factory ConsistencyDay.fromJson(Map<String, dynamic> j) => ConsistencyDay(
        date: asDate(j['date']),
        sessionCount: asInt(j['sessionCount']) ?? 0,
      );
}

/// Section 3 — the 12-week consistency window plus the (goal-dependent) % and streak.
class Consistency {
  const Consistency({
    required this.windowWeeks,
    required this.days,
    this.consistencyPct,
    required this.currentStreakWeeks,
  });

  final int windowWeeks;

  /// Only days with ≥1 completed session, date-ascending. The client renders the full grid.
  final List<ConsistencyDay> days;

  /// Weeks hitting goal ÷ weeks observed; null when there's no goal (hidden in the no-plan state).
  final int? consistencyPct;
  final int currentStreakWeeks;

  factory Consistency.fromJson(Map<String, dynamic> j) => Consistency(
        windowWeeks: asInt(j['windowWeeks']) ?? 12,
        days: asList(j['days'], ConsistencyDay.fromJson),
        consistencyPct: asInt(j['consistencyPct']),
        currentStreakWeeks: asInt(j['currentStreakWeeks']) ?? 0,
      );
}

/// Section 2 — a single top lift's strength direction over the trailing window, with a tiny spark
/// series for the inline `CustomPaint` sparkline. Honesty-gated server-side (≥4 qualifying sessions).
class LiftDirection {
  const LiftDirection({
    required this.exerciseId,
    this.exerciseName,
    required this.currentE1rmKg,
    required this.direction,
    required this.stalled,
    required this.stallSessions,
    required this.sparkE1rmKg,
  });

  final String exerciseId;
  final String? exerciseName;

  /// Latest session-best working-set e1RM.
  final double currentE1rmKg;
  final LiftTrendDirection direction;

  /// Best e1RM not exceeded in the last K=3 exposures.
  final bool stalled;

  /// Exposures since the last new best (0 if not stalled).
  final int stallSessions;

  /// Up to 8 recent session-best points, oldest→newest.
  final List<double> sparkE1rmKg;

  factory LiftDirection.fromJson(Map<String, dynamic> j) => LiftDirection(
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        currentE1rmKg: asDouble(j['currentE1rmKg']) ?? 0,
        direction: LiftTrendDirection.parse(j['direction']),
        stalled: asBool(j['stalled']),
        stallSessions: asInt(j['stallSessions']) ?? 0,
        sparkE1rmKg: _asDoubleList(j['sparkE1rmKg']),
      );
}

/// Section 4 — a PR teaser row reusing the existing `/api/me/records` shape (current best per lift,
/// e1RM-sorted). Taps through to the per-lift e1RM drill-down via `exerciseId`.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.estimatedOneRepMaxKg,
    this.achievedAt,
  });

  final String exerciseId;
  final String? exerciseName;
  final double weightKg;
  final int reps;
  final double estimatedOneRepMaxKg;
  final DateTime? achievedAt;

  factory PersonalRecord.fromJson(Map<String, dynamic> j) => PersonalRecord(
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        weightKg: asDouble(j['weightKg']) ?? 0,
        reps: asInt(j['reps']) ?? 0,
        estimatedOneRepMaxKg: asDouble(j['estimatedOneRepMaxKg']) ?? 0,
        achievedAt: asDate(j['achievedAt']),
      );
}

/// The whole trainee Progress home in one payload. Always present and empty-but-valid for new users
/// (`topLifts: []`, `recentPrs: []`, `consistency.days: []`).
class ProgressOverview {
  const ProgressOverview({
    required this.thisWeek,
    required this.consistency,
    required this.topLifts,
    required this.recentPrs,
    this.generatedAtUtc,
  });

  final WeekAdherence thisWeek;
  final Consistency consistency;

  /// 0–3 lifts, honesty-gated (each has ≥4 qualifying sessions in the 12-week window).
  final List<LiftDirection> topLifts;

  /// Top 3 PRs by e1RM.
  final List<PersonalRecord> recentPrs;
  final DateTime? generatedAtUtc;

  /// True for a brand-new trainee: never completed a session, so there's nothing to glance at yet.
  /// Drives the first-run hero (PHASE-1 §5) — distinguished from "thin data" by zero sessions AND
  /// no consistency days AND no PRs/lifts.
  bool get isNewUser =>
      thisWeek.completedSessions == 0 &&
      consistency.days.isEmpty &&
      topLifts.isEmpty &&
      recentPrs.isEmpty;

  factory ProgressOverview.fromJson(Map<String, dynamic> j) => ProgressOverview(
        thisWeek: j['thisWeek'] is Map<String, dynamic>
            ? WeekAdherence.fromJson(j['thisWeek'] as Map<String, dynamic>)
            : const WeekAdherence(completedSessions: 0, hasActivePlan: false),
        consistency: j['consistency'] is Map<String, dynamic>
            ? Consistency.fromJson(j['consistency'] as Map<String, dynamic>)
            : const Consistency(
                windowWeeks: 12, days: [], currentStreakWeeks: 0),
        topLifts: asList(j['topLifts'], LiftDirection.fromJson),
        recentPrs: asList(j['recentPrs'], PersonalRecord.fromJson),
        generatedAtUtc: asDate(j['generatedAtUtc']),
      );
}

/// Read a JSON array of numbers as a `List<double>`, coercing each element and dropping nulls.
List<double> _asDoubleList(Object? v) {
  if (v is! List) return const [];
  final out = <double>[];
  for (final e in v) {
    final d = asDouble(e);
    if (d != null) out.add(d);
  }
  return List.unmodifiable(out);
}

// ── Strength lifts (`GET /api/me/exercises/strength-lifts`) ──────────────────

/// One performed lift in the trailing window, for the Strength section's muscle-group / exercise
/// filtering (`GET /api/me/exercises/strength-lifts?weeks=N&muscleGroup=…`). This is the wider
/// per-lift list behind the home strip's top-3 glance: every lift the user has trained over the
/// period, each with its current e1RM, session count, and an honesty-gated direction.
///
/// The honesty gate is the same one the overview's top-lift strip uses: [hasTrend] is true only when
/// the server saw ≥4 qualifying sessions, and [direction] is meaningful ONLY then. A thin lift
/// (`hasTrend == false`) carries `direction = flat` purely as a default — the client must NOT render a
/// direction tag or a sparkline for it, only its name + e1RM + session count (never a fabricated
/// trend). [primaryMuscleGroup] is a camelCase token (one of chest|back|legs|shoulders|arms|core) or
/// null when the server couldn't resolve the lift's muscle — a null-group lift is never bucketed under
/// a fabricated chip.
class StrengthLift {
  const StrengthLift({
    required this.exerciseId,
    this.exerciseName,
    this.primaryMuscleGroup,
    required this.sessionCount,
    required this.currentE1rmKg,
    required this.hasTrend,
    required this.direction,
    required this.stalled,
    required this.stallSessions,
    required this.sparkE1rmKg,
  });

  final String exerciseId;
  final String? exerciseName;

  /// camelCase muscle token (chest|back|legs|shoulders|arms|core), or null when unresolved. Lowercased
  /// + trimmed on parse so the client can group/compare without re-normalizing. The chip row renders
  /// ONLY the groups that actually appear here — never a dead chip for an untrained (or null) group.
  final String? primaryMuscleGroup;

  /// Qualifying sessions for this lift over the window. Always shown (even for a thin lift) — it's the
  /// honest "N sessions" caption when there's no trend to draw.
  final int sessionCount;

  /// Latest session-best working-set e1RM.
  final double currentE1rmKg;

  /// True only when the honesty gate is met (≥4 qualifying sessions). When false the client shows
  /// e1RM + [sessionCount] only — no [LiftDirectionTag], no spark.
  final bool hasTrend;

  /// Trend direction — meaningful ONLY when [hasTrend]. Defaults to [LiftTrendDirection.flat] for a
  /// thin lift, but the client must not render it in that case.
  final LiftTrendDirection direction;

  /// Best e1RM not exceeded in the last K exposures (meaningful only with [hasTrend]).
  final bool stalled;

  /// Exposures since the last new best (0 if not stalled).
  final int stallSessions;

  /// Up to ~8 recent session-best points, oldest→newest. Empty / thin for a no-trend lift.
  final List<double> sparkE1rmKg;

  factory StrengthLift.fromJson(Map<String, dynamic> j) => StrengthLift(
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        // Normalize defensively: lowercase + trim so grouping/compare is canonical; a blank string
        // collapses to null so it's treated as "unresolved" (never an empty-label chip).
        primaryMuscleGroup: _muscleToken(j['primaryMuscleGroup']),
        sessionCount: asInt(j['sessionCount']) ?? 0,
        currentE1rmKg: asDouble(j['currentE1rmKg']) ?? 0,
        hasTrend: asBool(j['hasTrend']),
        direction: LiftTrendDirection.parse(j['direction']),
        stalled: asBool(j['stalled']),
        stallSessions: asInt(j['stallSessions']) ?? 0,
        sparkE1rmKg: _asDoubleList(j['sparkE1rmKg']),
      );
}

/// The `strength-lifts` payload — every performed lift over the window, sorted by [StrengthLift.currentE1rmKg]
/// desc server-side. Always present and empty-but-valid for a new user (`lifts: []`). The client
/// derives the muscle-chip set from the non-null [StrengthLift.primaryMuscleGroup] values present here.
class StrengthLifts {
  const StrengthLifts({required this.lifts});

  /// All performed lifts, e1RM-desc (server-sorted). May be empty.
  final List<StrengthLift> lifts;

  factory StrengthLifts.fromJson(Map<String, dynamic> j) =>
      StrengthLifts(lifts: asList(j['lifts'], StrengthLift.fromJson));
}

/// Canonicalize a wire muscle-group token: lowercase + trim, collapsing null/blank to null (so an
/// unresolved group is never rendered as an empty chip). Kept loose — any non-blank string is kept
/// as-is, so an unexpected server token still groups consistently rather than throwing.
String? _muscleToken(Object? v) {
  final s = v?.toString().trim().toLowerCase();
  if (s == null || s.isEmpty) return null;
  return s;
}

// ── Phase 2 — per-lift e1RM series (`GET /api/me/exercises/{id}/e1rm-series`) ──

/// One session-best e1RM point on the per-lift trend (API-CONTRACTS §2). `isPr` is derived
/// server-side from the series itself (a point that strictly exceeds the running max), never from
/// `/api/me/records` — so the PR markers on the chart line up exactly with the plotted points.
class E1rmSeriesPoint {
  const E1rmSeriesPoint({
    this.date,
    required this.sessionBestE1rmKg,
    this.topSetWeightKg,
    this.topSetReps,
    required this.isPr,
  });

  /// Session day (local). Null only on a malformed payload — dropped before plotting.
  final DateTime? date;

  /// `MAX(EstimatedOneRepMaxKg)` over that session's qualifying working sets.
  final double sessionBestE1rmKg;

  /// The set that produced the session best (for the "last time" reference); optional on the wire.
  final double? topSetWeightKg;
  final int? topSetReps;

  /// True when this point set a new running-max e1RM (an amber PR marker on the line).
  final bool isPr;

  factory E1rmSeriesPoint.fromJson(Map<String, dynamic> j) => E1rmSeriesPoint(
        date: asDate(j['date']),
        sessionBestE1rmKg: asDouble(j['sessionBestE1rmKg']) ?? 0,
        topSetWeightKg: asDouble(j['topSetWeightKg']),
        topSetReps: asInt(j['topSetReps']),
        isPr: asBool(j['isPr']),
      );
}

/// The full per-lift drill-down payload: the e1RM series plus the same direction/stall summary the
/// home strip shows (so the detail header restates the home verdict). Empty `points` for a lift with
/// no qualifying working sets → the screen shows a "not enough data yet" empty state, never a line.
class ExerciseE1rmSeries {
  const ExerciseE1rmSeries({
    required this.exerciseId,
    this.exerciseName,
    required this.points,
    required this.currentE1rmKg,
    required this.deltaKgVsTrailing4w,
    required this.direction,
    required this.stalled,
    required this.stallSessions,
  });

  final String exerciseId;
  final String? exerciseName;

  /// Session-best points, oldest→newest.
  final List<E1rmSeriesPoint> points;

  /// Latest session-best working-set e1RM.
  final double currentE1rmKg;

  /// Current − mean(session-best e1RM over the prior 4 weeks).
  final double deltaKgVsTrailing4w;
  final LiftTrendDirection direction;

  /// Best e1RM not exceeded in the last K=3 exposures.
  final bool stalled;

  /// Exposures since the last new best (0 if not stalled).
  final int stallSessions;

  /// A trend line needs ≥4 points (the honesty gate); below that the screen shows the raw dots and a
  /// "log a few more" invite (DRILL-DOWNS §1). Mirrors the server's top-lift selection floor.
  bool get hasTrend => points.length >= 4;

  factory ExerciseE1rmSeries.fromJson(Map<String, dynamic> j) => ExerciseE1rmSeries(
        exerciseId: j['exerciseId'].toString(),
        exerciseName: asString(j['exerciseName']),
        points: asList(j['points'], E1rmSeriesPoint.fromJson),
        currentE1rmKg: asDouble(j['currentE1rmKg']) ?? 0,
        deltaKgVsTrailing4w: asDouble(j['deltaKgVsTrailing4w']) ?? 0,
        direction: LiftTrendDirection.parse(j['direction']),
        stalled: asBool(j['stalled']),
        stallSessions: asInt(j['stallSessions']) ?? 0,
      );
}

// ── Phase 2/3 — body-metric series (`GET /api/me/progress/metrics/series`) ──

/// One latest-per-day metric reading (API-CONTRACTS §3). The backend already collapses to one row
/// per local day, so the client plots `points` as-is.
class MetricSeriesPoint {
  const MetricSeriesPoint({this.localDate, required this.value});

  /// Local calendar day of the reading. Null only on a malformed payload — dropped before plotting.
  final DateTime? localDate;
  final double value;

  factory MetricSeriesPoint.fromJson(Map<String, dynamic> j) => MetricSeriesPoint(
        localDate: asDate(j['localDate']),
        value: asDouble(j['value']) ?? 0,
      );
}

/// A body-metric trend (bodyweight today; sleep later). `unit` labels the axis; empty `points`
/// drives the Body section's empty-state invite — never a faked line over sparse data.
class MetricSeries {
  const MetricSeries({
    required this.type,
    this.unit,
    required this.points,
  });

  /// The requested metric type, echoed back (free-text, normalized server-side).
  final String type;

  /// Display unit (e.g. "kg"); may be null/absent on older payloads.
  final String? unit;

  /// Latest-per-day readings, date-ascending.
  final List<MetricSeriesPoint> points;

  /// An empty-but-valid series (new user, or no weigh-ins in range) → render the invite, not a chart.
  bool get isEmpty => points.isEmpty;

  factory MetricSeries.fromJson(Map<String, dynamic> j) => MetricSeries(
        type: asString(j['type']) ?? '',
        unit: asString(j['unit']),
        points: asList(j['points'], MetricSeriesPoint.fromJson),
      );
}

// ── Phase 3 — nutrition adherence (`GET /api/me/progress/nutrition-adherence`) ──

/// One day's finalized nutrition adherence (API-CONTRACTS §5 — the shape the backend program
/// freezes around `DailyNutritionLog.AdherencePct`, Decision **D13**). `pct` is 0–100; `date` is the
/// log's local day. A day with no closed log simply doesn't appear in the series.
///
/// Wire shape is the **frozen** `DailyAdherenceDto(LocalDate, AdherencePct, PlannedCount,
/// CompletedCount)` serialized camelCase (`localDate`, `adherencePct`, …), so `fromJson` reads those
/// exact keys — not the Dart field names. The per-day payload now also carries the **calories** the
/// CALORIES TREND renders: `consumedKcal` (all-source, ad-hoc + planned) and the plan-derived
/// `targetKcal` (null when no plan target / hidden) — both parsed defensively so an older payload that
/// omits them degrades to consumed=0 / no-target rather than throwing.
class DailyAdherence {
  const DailyAdherence({
    this.date,
    required this.pct,
    this.consumedKcal = 0,
    this.targetKcal,
  });

  /// The log's local calendar day. Null only on a malformed payload — dropped before plotting.
  final DateTime? date;

  /// Finalized adherence percent (0–100): completed/substituted planned items ÷ planned items.
  final int pct;

  /// Calories consumed that day, all-source (ad-hoc self-logged + planned). Defaults to 0 on an older
  /// payload that predates the field — the trend then simply draws a zero-height bar for that day.
  final int consumedKcal;

  /// Plan-derived target calories for that day, or null when there's no plan target (or it's hidden).
  /// The trend draws the dashed "Plan" line and the deficit/surplus tint ONLY on days where this is
  /// present — never a fabricated target on a no-target day.
  final int? targetKcal;

  factory DailyAdherence.fromJson(Map<String, dynamic> j) => DailyAdherence(
        date: asDate(j['localDate']),
        pct: (asInt(j['adherencePct']) ?? 0).clamp(0, 100),
        // Defensive for older payloads: consumed defaults to 0, target stays null when absent.
        consumedKcal: (asInt(j['consumedKcal']) ?? 0).clamp(0, 1 << 30),
        targetKcal: asInt(j['targetKcal']),
      );
}

/// One logged day for the **CALORIES-LOGGED LIST** (the ad-hoc-friendly companion to the calories
/// trend). Unlike [DailyAdherence] (the plan-only trend series under `days`), this row exists for
/// EVERY day in the endpoint window that has ≥1 logged item from ANY source — plan or ad-hoc — so a
/// no-plan logger (whose plan-only trend is empty) still sees what they actually logged.
///
/// `consumedKcal` is the all-source adherent-item kcal sum (same semantics as the per-day
/// `DailyAdherence.consumedKcal`); `targetKcal` is the plan-meal kcal sum for that day, nullable
/// (null when there's no plan / no planned energy / macro targets are hidden) — never fabricated.
class DayCalories {
  const DayCalories({
    this.localDate,
    required this.consumedKcal,
    this.targetKcal,
  });

  /// The logged day's local calendar day. Null only on a malformed payload — dropped before rendering.
  final DateTime? localDate;

  /// Consumed kcal that day, all-source (ad-hoc self-logged + planned, adherent items only).
  final int consumedKcal;

  /// Plan-derived target kcal for that day, or null when there's no plan target (or it's hidden). The
  /// list shows an under/over delta ONLY where this is present — never a fabricated target.
  final int? targetKcal;

  factory DayCalories.fromJson(Map<String, dynamic> j) => DayCalories(
        localDate: asDate(j['localDate']),
        consumedKcal: (asInt(j['consumedKcal']) ?? 0).clamp(0, 1 << 30),
        targetKcal: asInt(j['targetKcal']),
      );
}

/// Recent nutrition adherence for the home Body→nutrition card (MOBILE-DASHBOARD §5 / Decision
/// **D13**). `hasPlan` gates the whole card: when false the trainee is following no meal plan, so the
/// card shows a "follow a meal plan" invite instead of a (meaningless) 0%. `recentDays` is the
/// trailing window (latest last), and `currentWeekAvgPct` is the server's pre-rolled current-week
/// mean — the client never fabricates a target, only renders what the nutrition program computes.
///
/// Calorie/macro **vs-target** is deliberately absent (D13 defers it to the nutrition program's
/// daily-target entity); this card is adherence-% only.
class NutritionAdherence {
  const NutritionAdherence({
    required this.hasPlan,
    this.currentWeekAvgPct,
    required this.recentDays,
    this.loggedDaysThisWeek = 0,
    this.hasAnyLogging = false,
    this.caloriesByDay = const [],
  });

  /// Whether the trainee currently follows a meal plan. False → the card shows its invite, never a
  /// ring (a 0% ring on no plan reads as failure, exactly the dishonesty this page forbids).
  final bool hasPlan;

  /// Current-week mean adherence (0–100), rolled up server-side; null when there's no plan or no
  /// closed days this week (the card then leans on the recent strip / invite instead of a ring).
  final int? currentWeekAvgPct;

  /// Recent finalized days, oldest→newest (typically the trailing ~7), for the CALORIES TREND bars
  /// (each carries `consumedKcal` + optional `targetKcal`).
  final List<DailyAdherence> recentDays;

  /// Count of distinct local days the trainee logged nutrition this week — the **honest ad-hoc
  /// tracking signal**. Ad-hoc (no-plan) days are 100% adherence by convention so they're absent from
  /// the adherence %; this count instead makes self-logging *count* on Progress without fabricating a
  /// 100% ring. Surfaced as the trend's small days-logged sub-caption.
  final int loggedDaysThisWeek;

  /// Whether the trainee has logged any nutrition at all (planned or ad-hoc). Gates the no-plan card:
  /// true → the ad-hoc tracking state; false → the "follow a meal plan" invite (genuinely nothing yet).
  final bool hasAnyLogging;

  /// Every day in the endpoint window with ≥1 logged item, ANY source (plan or ad-hoc), date-ASCENDING
  /// — the **CALORIES-LOGGED LIST** source. This is the ad-hoc-friendly companion to [recentDays]: a
  /// no-plan logger has an empty plan-only [recentDays] trend but still gets rows here. Empty on an
  /// older payload that predates the field (the list then simply doesn't render).
  final List<DayCalories> caloriesByDay;

  /// Wire shape is the **frozen** `NutritionAdherenceDto(HasPlan, Days, CurrentWeekAvgPct)`
  /// serialized camelCase, extended (D-self-train) with `loggedDaysThisWeek` (int) + `hasAnyLogging`
  /// (bool) so ad-hoc self-logging is recorded on Progress, so the recent series arrives under `days`
  /// (not `recentDays`). Both new fields parse defensively (default 0 / false on an older payload).
  /// `caloriesByDay` (the all-source CALORIES-LOGGED LIST) parses defensively too: an older payload
  /// missing the key degrades to an empty list rather than throwing.
  factory NutritionAdherence.fromJson(Map<String, dynamic> j) => NutritionAdherence(
        hasPlan: asBool(j['hasPlan']),
        currentWeekAvgPct: asInt(j['currentWeekAvgPct']),
        recentDays: asList(j['days'], DailyAdherence.fromJson),
        loggedDaysThisWeek: asInt(j['loggedDaysThisWeek']) ?? 0,
        hasAnyLogging: asBool(j['hasAnyLogging']),
        caloriesByDay: asList(j['caloriesByDay'], DayCalories.fromJson),
      );
}
