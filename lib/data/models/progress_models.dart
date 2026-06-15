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
/// e1RM-sorted). Display-only in Phase 1.
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
/// exact keys — not the Dart field names.
class DailyAdherence {
  const DailyAdherence({this.date, required this.pct});

  /// The log's local calendar day. Null only on a malformed payload — dropped before plotting.
  final DateTime? date;

  /// Finalized adherence percent (0–100): completed/substituted planned items ÷ planned items.
  final int pct;

  factory DailyAdherence.fromJson(Map<String, dynamic> j) => DailyAdherence(
        date: asDate(j['localDate']),
        pct: (asInt(j['adherencePct']) ?? 0).clamp(0, 100),
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
  });

  /// Whether the trainee currently follows a meal plan. False → the card shows its invite, never a
  /// ring (a 0% ring on no plan reads as failure, exactly the dishonesty this page forbids).
  final bool hasPlan;

  /// Current-week mean adherence (0–100), rolled up server-side; null when there's no plan or no
  /// closed days this week (the card then leans on the recent strip / invite instead of a ring).
  final int? currentWeekAvgPct;

  /// Recent finalized days, oldest→newest (typically the trailing ~7), for the compact bar strip.
  final List<DailyAdherence> recentDays;

  /// No closed days to chart yet (but a plan exists) → render a "log a day" nudge, not an empty strip.
  bool get isEmpty => recentDays.isEmpty;

  /// Wire shape is the **frozen** `NutritionAdherenceDto(HasPlan, Days, CurrentWeekAvgPct)`
  /// serialized camelCase, so the recent series arrives under `days` (not `recentDays`).
  factory NutritionAdherence.fromJson(Map<String, dynamic> j) => NutritionAdherence(
        hasPlan: asBool(j['hasPlan']),
        currentWeekAvgPct: asInt(j['currentWeekAvgPct']),
        recentDays: asList(j['days'], DailyAdherence.fromJson),
      );
}
