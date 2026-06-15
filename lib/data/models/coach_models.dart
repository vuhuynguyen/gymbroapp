import 'dart:math' as math;

import '../../core/utils/json.dart';
import '../../domain/enums.dart';
import 'plan_models.dart';
import 'session_models.dart';

/// A coach's client row: the member joined with their active assignment (plan name + visibility).
class ClientSummary {
  const ClientSummary({
    required this.userId,
    required this.name,
    this.activeAssignmentId,
    this.planName,
    this.visibility,
    this.frequency,
  });

  final String userId;
  final String name;
  final String? activeAssignmentId;
  final String? planName;
  final PlanVisibilityMode? visibility;
  final int? frequency;

  bool get hasActivePlan => activeAssignmentId != null;
  String get initial => name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
}

/// Everything the Client Monitor screen needs for one trainee.
class ClientMonitorData {
  const ClientMonitorData({required this.assignments, required this.sessions});

  final List<AssignedPlan> assignments;
  final List<SessionSummary> sessions;
}

// ── Coach progress roster (Phase 2b) — GET /api/clients/progress/roster ──
//
// The coach home: an at-risk-first triage list, tenant-scoped (own gym only). The roster `Status` is
// computed server-side from cheap signals only (adherence band + last-active gap) — "stalled" is NOT
// at roster scale (Decision D4); it is resolved on client open (the per-client strength detail).
// See gymbro/docs/progress/API-CONTRACTS.md §4 and COACH-VS-TRAINEE.md §2.

/// The triage verdict for one roster row. Serialized as a camelCase string on the wire
/// (`onTrack`/`drifting`/`quiet`), parsed case/whitespace-tolerantly; an unrecognized/null value
/// falls back to [onTrack] (the "skip — spend attention elsewhere" state) so a stray payload never
/// throws and never over-alarms the coach.
enum RosterStatus {
  onTrack,
  drifting,
  quiet;

  /// `true` for the states the coach should triage first (the roster sorts these to the top).
  bool get isAtRisk => this != RosterStatus.onTrack;

  static RosterStatus parse(Object? v) {
    final s = v?.toString().trim().toLowerCase();
    switch (s) {
      case 'quiet':
        return RosterStatus.quiet;
      case 'drifting':
        return RosterStatus.drifting;
      case 'ontrack':
      case 'on_track':
      case 'on track':
      default:
        return RosterStatus.onTrack;
    }
  }
}

/// One client row on the coach roster — the verdict plus the cheap signals behind it. All fields are
/// tenant-scoped (own gym): `lastActiveAt` is `MAX(StartedAt)` in this gym, `completedThisWeek` /
/// `weeklyGoal` are this gym's assignment goal. Cross-gym training is invisible by design (the screen
/// captions "this gym only") — a client who trains elsewhere can legitimately read `quiet` here.
class ClientStatus {
  const ClientStatus({
    required this.traineeId,
    required this.displayName,
    this.lastActiveAt,
    required this.completedThisWeek,
    this.weeklyGoal,
    required this.status,
  });

  final String traineeId;
  final String displayName;

  /// `MAX(WorkoutSession.StartedAt)` tenant-scoped; null if the client has never trained in this gym.
  final DateTime? lastActiveAt;

  /// `Status == Completed` sessions this ISO week, tenant-scoped.
  final int completedThisWeek;

  /// Authoritative in-gym `FrequencyDaysPerWeek`; null when there's no active assignment in this gym.
  final int? weeklyGoal;
  final RosterStatus status;

  bool get hasGoal => weeklyGoal != null && weeklyGoal! > 0;

  /// Ring fraction 0..1 — only meaningful when there's a positive goal.
  double get ringValue => hasGoal ? (completedThisWeek / weeklyGoal!).clamp(0.0, 1.0) : 0;

  String get initial => displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '?';

  factory ClientStatus.fromJson(Map<String, dynamic> j) => ClientStatus(
        traineeId: (j['traineeId'] ?? j['userId'] ?? '').toString(),
        displayName: asString(j['displayName']) ?? asString(j['name']) ?? '',
        lastActiveAt: asDate(j['lastActiveAt']),
        completedThisWeek: asInt(j['completedThisWeek']) ?? 0,
        weeklyGoal: asInt(j['weeklyGoal']),
        status: RosterStatus.parse(j['status']),
      );
}

/// The roster payload: an at-risk-first list of [ClientStatus]. Always present and empty-but-valid for
/// a gym with no members who have sessions (`items: []`).
class Roster {
  const Roster({required this.items});

  final List<ClientStatus> items;

  bool get isEmpty => items.isEmpty;

  /// At-risk-first ordering (management by exception): Quiet, then Drifting, then On track. Within a
  /// status band, the most-stale client (oldest `lastActiveAt`, nulls first) leads — the one most in
  /// need of a message. Stable for ties so the server's order is otherwise preserved.
  List<ClientStatus> get triaged {
    int rank(RosterStatus s) => switch (s) {
          RosterStatus.quiet => 0,
          RosterStatus.drifting => 1,
          RosterStatus.onTrack => 2,
        };
    final out = [...items];
    out.sort((a, b) {
      final byStatus = rank(a.status).compareTo(rank(b.status));
      if (byStatus != 0) return byStatus;
      // Older / never-active first (a null lastActiveAt is the most-stale → sorts first).
      final at = a.lastActiveAt;
      final bt = b.lastActiveAt;
      if (at == null && bt == null) return 0;
      if (at == null) return -1;
      if (bt == null) return 1;
      return at.compareTo(bt);
    });
    return out;
  }

  factory Roster.fromJson(Map<String, dynamic> j) =>
      Roster(items: asList(j['items'], ClientStatus.fromJson));
}

// ── Coach per-client workload (Phase 4) — GET /api/clients/{id}/progress/load ──
//
// Acute-vs-chronic *load*, tenant-scoped (own gym only): the client's 7-day acute training volume vs
// their chronic weekly-average (a 4-week / 28-day rolling weekly mean). Surfaced as TWO SEPARATE BARS,
// NEVER an ACWR ratio — RPE is integer/sparse, so the load is volume-based, and a ratio would read as
// a (false) injury predictor (Decision D14 / COACH-VS-TRAINEE.md §3, audit R10). The card shows a
// SOFT, non-medical trend chip only; no ratio, no number presented as a risk threshold.
//
// This rides the same separate tenant-scoped handler family as the strength read (EF tenant filter ON,
// never `QueryOwnAcrossGyms`) — a client's cross-gym training is invisible here by design.

/// How this gym's recent (7-day) volume compares to the client's own chronic weekly average. Serialized
/// as a camelCase string on the wire (`detraining`/`steady`/`ramping`), parsed case/whitespace-tolerantly.
///
/// An unrecognized/null value falls back to [steady] — the neutral, no-alarm state — so a stray payload
/// never throws and never over-alarms the coach. Deliberately *soft*, descriptive language (never a
/// medical or injury claim): GymBro is descriptive by design, prescription stays with the human coach.
enum LoadTrend {
  /// Acute well below the chronic average — the client is easing off / training less than their norm.
  detraining,

  /// Acute close to the chronic average — holding steady.
  steady,

  /// Acute well above the chronic average — ramping volume up.
  ramping;

  static LoadTrend parse(Object? v) {
    final s = v?.toString().trim().toLowerCase();
    switch (s) {
      case 'detraining':
      case 'easing':
      case 'easingoff':
      case 'easing_off':
        return LoadTrend.detraining;
      case 'ramping':
      case 'rampingup':
      case 'ramping_up':
        return LoadTrend.ramping;
      case 'steady':
      default:
        return LoadTrend.steady;
    }
  }
}

/// The coach per-client workload payload (Decision D14). Two volumes the card renders as two separate
/// bars — never a ratio:
///
/// - [acuteVolumeKg]: the client's total working volume in this gym over the last **7 days**.
/// - [chronicWeeklyVolumeKg]: their **chronic weekly average** — the mean weekly volume over the
///   trailing 4 weeks (28 days), the baseline the acute week is read against.
///
/// All tenant-scoped (own gym only). A client who trains elsewhere can legitimately read low here — the
/// card captions "this gym only". Empty-but-valid for a client with no logged volume (both zero,
/// [LoadTrend.steady]).
class AcuteChronicLoad {
  const AcuteChronicLoad({
    required this.acuteVolumeKg,
    required this.chronicWeeklyVolumeKg,
    required this.trend,
    this.unit,
  });

  /// Total working volume (Σ weight×reps) in this gym over the last 7 days. ≥ 0.
  final double acuteVolumeKg;

  /// Chronic weekly-average volume (mean weekly volume over the trailing 4 weeks). ≥ 0.
  final double chronicWeeklyVolumeKg;

  /// The soft, non-medical trend label the chip renders.
  final LoadTrend trend;

  /// Volume unit for labels (e.g. "kg"); may be null/absent on older payloads — the card defaults "kg".
  final String? unit;

  /// True once there's any volume to compare — both bars zero ⇒ nothing to show (render the quiet
  /// empty card rather than two empty bars + a misleading "steady" chip).
  bool get hasData => acuteVolumeKg > 0 || chronicWeeklyVolumeKg > 0;

  /// The taller of the two bars — the painter scales both to this so the comparison is honest
  /// (zero-baseline, shared scale). 0 when there's no data.
  double get peakKg => math.max(acuteVolumeKg, chronicWeeklyVolumeKg);

  factory AcuteChronicLoad.fromJson(Map<String, dynamic> j) => AcuteChronicLoad(
        // Tolerant of a couple of plausible field spellings while the backend shape is finalized
        // (D14 is design-frozen; API-CONTRACTS has no §6 for /load yet): prefer the explicit
        // `acuteVolumeKg` / `chronicWeeklyVolumeKg`, fall back to shorter aliases.
        acuteVolumeKg:
            _nonNeg(asDouble(j['acuteVolumeKg']) ?? asDouble(j['acuteKg']) ?? asDouble(j['acute'])),
        chronicWeeklyVolumeKg: _nonNeg(asDouble(j['chronicWeeklyVolumeKg']) ??
            asDouble(j['chronicKg']) ??
            asDouble(j['chronicWeeklyKg']) ??
            asDouble(j['chronic'])),
        trend: LoadTrend.parse(j['trend']),
        unit: asString(j['unit']),
      );
}

double _nonNeg(double? v) => (v == null || v < 0) ? 0 : v;
