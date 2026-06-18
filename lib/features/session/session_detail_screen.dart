import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/app_time_zone.dart';
import '../../data/models/exercise_models.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session_metrics.dart';
import '../../shared/widgets/widgets.dart';
import '../log/log_providers.dart';
import 'live_session_screen.dart' show GuideButton;
import 'start_actions.dart';

/// Session muscle heat-map data — the union of every exercise's *detailed* (fine) worked muscles across the
/// session, primary winning over secondary. Keyed by the session's distinct exercise ids (sorted, comma-
/// joined) so it caches per session. Best-effort: a detail that fails to load is skipped, so the map only
/// ever lights muscles we can resolve — never fabricated. Detailed slugs live on the detail endpoint (not
/// the summary catalog), so this fans out one `getById` per distinct exercise, lazily on sheet-open.
final _sessionMuscleMapProvider = FutureProvider.family<
    ({List<String> primary, List<String> secondary}), String>((ref, idsKey) async {
  final ids = idsKey.split(',').where((s) => s.isNotEmpty).toList();
  if (ids.isEmpty) {
    return (primary: const <String>[], secondary: const <String>[]);
  }
  final repo = ref.read(exerciseRepositoryProvider);
  final details = await Future.wait(ids.map((id) async {
    try {
      return await repo.getById(id);
    } catch (_) {
      return null;
    }
  }));
  final primary = <String>{};
  final secondary = <String>{};
  for (final d in details) {
    if (d == null) continue;
    primary.addAll(d.detailedPrimaryMuscles);
    secondary.addAll(d.detailedSecondaryMuscles);
  }
  secondary.removeAll(primary); // a muscle that's a primary mover in any lift shows as primary
  return (primary: primary.toList(), secondary: secondary.toList());
});

/// One exercise's full detail (for its own muscle map), best-effort + cached per id.
final _exerciseDetailProvider =
    FutureProvider.family<ExerciseDetail?, String>((ref, id) async {
  try {
    return await ref.read(exerciseRepositoryProvider).getById(id);
  } catch (_) {
    return null;
  }
});

/// Post-session summary: duration, volume, sets, RPE, PRs + per-exercise set breakdown. Reached from
/// a history row or straight after finishing (`fromFinish`). Volume is kg (the stored unit); RPE is
/// the stored 1-10 integer. The server applies plan visibility, so we render the payload as-is.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({
    required this.sessionId,
    this.fromFinish = false,
    this.mine = false,
    super.key,
  });
  final String sessionId;
  final bool fromFinish;

  /// True for the trainee's OWN session → cross-gym `/api/me/sessions/{id}`. False for the coach
  /// viewing a client's session → tenant-scoped `/api/sessions/{id}` (WorkoutLogViewAll).
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mine
        ? mySessionDetailProvider(sessionId)
        : sessionDetailProvider(sessionId);
    final detail = ref.watch(provider);
    return Scaffold(
      body: Column(
        children: [
          GbDetailHeader(
            title: fromFinish ? 'Workout complete' : 'Session detail',
            leadingIcon: fromFinish ? Icons.close : Icons.chevron_left,
            leadingLabel: fromFinish ? 'Close' : 'Back',
            onLeading: () => fromFinish ? context.go('/log') : context.pop(),
          ),
          Expanded(
            child: AsyncValueView(
              value: detail,
              onRetry: () async => ref.invalidate(provider),
              data: (d) {
                // "Repeat workout" = start a NEW session from the SAME assignment + workout. Only the
                // trainee's own plan-sourced sessions can repeat (ad-hoc has no assignment to reuse;
                // the coach view is read-only). No dedicated repeat endpoint — this reuses the real
                // start-from-assignment flow.
                final canRepeat = mine &&
                    d.source != SessionSource.adhoc &&
                    d.planAssignmentId != null &&
                    d.plannedWorkoutId != null;
                // Edit a finished workout in place — own, completed sessions only (abandoned stays
                // read-only; the coach view is read-only). Opens the live editor in edit mode.
                final canEdit = mine && d.status == SessionStatus.completed;
                return Column(
                  children: [
                    Expanded(child: _Body(detail: d, fromFinish: fromFinish)),
                    if (canEdit || canRepeat)
                      _SessionActionBar(
                        onEdit: canEdit
                            ? () => context.push('/session/${d.id}')
                            : null,
                        onRepeat: canRepeat
                            ? () => startFromAssignment(
                                  context,
                                  ref,
                                  planAssignmentId: d.planAssignmentId!,
                                  plannedWorkoutId: d.plannedWorkoutId!,
                                )
                            : null,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned footer with the Session Detail actions: "Edit" (fix a finished workout in place) and/or
/// "Repeat workout". Either may be null; when both show, Edit is the secondary (outlined) action.
class _SessionActionBar extends StatelessWidget {
  const _SessionActionBar({this.onEdit, this.onRepeat});
  final VoidCallback? onEdit;
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final edit = onEdit == null
        ? null
        : GbButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            full: true,
            variant: GbButtonVariant.outlined,
            severity: GbButtonSeverity.secondary,
            onPressed: onEdit!);
    final repeat = onRepeat == null
        ? null
        : GbButton(
            label: 'Repeat workout',
            icon: Icons.play_arrow,
            full: true,
            onPressed: onRepeat!);
    return Container(
      decoration: BoxDecoration(
          color: gb.card,
          border: Border(top: BorderSide(color: gb.borderCard))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm,
              AppSpacing.screenH, AppSpacing.sm),
          child: Row(
            children: [
              if (edit != null) Expanded(child: edit),
              if (edit != null && repeat != null)
                const SizedBox(width: AppSpacing.sm),
              if (repeat != null) Expanded(child: repeat),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.fromFinish});
  final SessionDetail detail;
  final bool fromFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final d = detail;
    final prExerciseIds = d.prs.map((p) => p.exerciseId).toSet();
    final at = d.startedAt ?? d.completedAt;

    // Mode-aware summary — grounded in logged data, never fabricated. A session with no
    // strength/bodyweight lifting shows the cardio summary instead of volume/sets.
    final cardio = isCardioSession(d.exercises);
    final working = workingSetCount(d.exercises);
    final ct = cardio ? cardioTotals(d.exercises) : null;
    // Muscle groups come from the exercise catalog (same source the live logger uses); skipped for
    // cardio. Null catalog (still loading / offline) simply yields no muscle bars.
    final catalog = ref.watch(exerciseCatalogProvider).valueOrNull;
    List<({String group, bool isPrimary})> musclesOf(String id) => [
          for (final m in (catalog?[id]?.muscles ?? const <ExerciseMuscle>[]))
            (group: m.name, isPrimary: m.isPrimary)
        ];
    final byMuscle = cardio
        ? const <String, MuscleInvolvement>{}
        : muscleInvolvement(d.exercises, musclesOf);
    // Which exercises drove each muscle group's sets — revealed when a muscle row is expanded.
    final muscleBreakdown = cardio
        ? const <String, List<MuscleExerciseContribution>>{}
        : muscleExerciseBreakdown(
            d.exercises,
            musclesOf,
            (e) => e.exerciseName ?? catalog?[e.exerciseId]?.name ?? 'Exercise',
          );
    // Distinct exercise ids (sorted) key the session heat-map fetch in the (i) detail sheet.
    final muscleMapKey =
        (d.exercises.map((e) => e.exerciseId).toSet().toList()..sort())
            .join(',');
    // Progress vs the trainee's previous session (the backend ships per-exercise lastPerformed).
    final progress = cardio ? null : sessionProgress(d.exercises);

    final metaParts = <String>[
      if (d.programName != null && d.programName!.isNotEmpty) d.programName!,
      if (d.planWeek != null) 'Week ${d.planWeek}',
      if (at != null) _dateLabel(at, d.clientTimezone),
      if (at != null) _timeLabel(at, d.clientTimezone),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 2, AppSpacing.md, AppSpacing.md + 2, AppSpacing.md),
      children: [
        if (fromFinish) ...[
          const _SuccessBanner(),
          const SizedBox(height: AppSpacing.md),
        ],

        // Title block — big workout name, source tag, optional PR chip + meta line.
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              d.workoutNameSnapshot ?? d.programName ?? 'Session',
              style: AppText.statNumber.copyWith(fontSize: 25, color: gb.ink),
            ),
            SourceTag(d.source),
            if (d.prs.isNotEmpty) const PrChip(),
          ],
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(metaParts.join(' · '),
              style: AppText.meta.copyWith(fontSize: 13, color: gb.grey500)),
        ],
        const SizedBox(height: AppSpacing.md),

        // Stat grid — mode-aware. Lifting: duration · volume / working-sets · avg RPE · PRs.
        // Cardio (no lifting): duration · distance / calories · avg HR · avg RPE.
        Row(
          children: [
            Expanded(
              child: GbStatTile(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: d.durationSeconds != null
                    ? formatDurationCompact(d.durationSeconds!)
                    : '—',
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: cardio
                  ? GbStatTile(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: _fmtDistanceValue(ct!.distanceM),
                      unit: _fmtDistanceUnit(ct.distanceM),
                      accent: gb.primary500,
                    )
                  : GbStatTile(
                      icon: Icons.bar_chart,
                      label: 'Volume',
                      value: _fmtVolume(d.totalVolumeKg),
                      unit: 'kg',
                      accent: gb.primary500,
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          children: [
            Expanded(
              child: cardio
                  ? GbStatTile(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Calories',
                      value: ct!.calories > 0 ? '${ct.calories}' : '—',
                      unit: ct.calories > 0 ? 'kcal' : null,
                      accent: gb.amber,
                    )
                  : GbStatTile(
                      icon: Icons.layers_outlined,
                      label: 'Working sets',
                      value: '$working',
                    ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: cardio
                  ? GbStatTile(
                      icon: Icons.favorite_outline,
                      label: 'Avg HR',
                      value:
                          ct!.avgHeartRate != null ? '${ct.avgHeartRate}' : '—',
                      unit: ct.avgHeartRate != null ? 'bpm' : null,
                      accent: gb.danger,
                    )
                  : GbStatTile(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Avg RPE',
                      value: d.rpeOverall != null ? '${d.rpeOverall}' : '—',
                      unit: d.rpeOverall != null ? '/10' : null,
                      accent: gb.amber,
                    ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: cardio
                  ? GbStatTile(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Avg RPE',
                      value: d.rpeOverall != null ? '${d.rpeOverall}' : '—',
                      unit: d.rpeOverall != null ? '/10' : null,
                      accent: gb.amber,
                    )
                  : GbStatTile(
                      icon: Icons.emoji_events_outlined,
                      label: 'PRs',
                      value: '${d.prs.length}',
                      accent: gb.amber,
                    ),
            ),
          ],
        ),

        // Progress vs the previous session (lifting only; shown once there's a prior to compare to).
        if (progress != null && progress.compared > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _ProgressVsLast(progress: progress),
        ],

        // Muscles trained — working sets per muscle group, split primary vs secondary (lifting only).
        if (byMuscle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                  child: GbSectionTitle('Muscles trained',
                      count: byMuscle.length)),
              // (i) → the full breakdown sheet; the overview stays just the bars.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    _showMuscleDetail(
                        context, byMuscle, muscleBreakdown, muscleMapKey),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child:
                      Icon(Icons.info_outline, size: 18, color: gb.grey400),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _MuscleBars(
              byMuscle: byMuscle, breakdown: muscleBreakdown, compact: true),
        ],

        if (d.notes != null && d.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          GbCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: AppSizes.iconLg, color: gb.grey400),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(d.notes!,
                      style: TextStyle(
                          fontSize: 14, height: 1.45, color: gb.grey700)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        GbSectionTitle('Exercises', count: d.exercises.length),
        const SizedBox(height: AppSpacing.sm - 2),

        for (final (i, e) in d.exercises.indexed) ...[
          _ExerciseBreakdown(
              exercise: e,
              isPr: prExerciseIds.contains(e.exerciseId),
              order: i + 1),
          const SizedBox(height: AppSpacing.sm - 2),
        ],
      ],
    );
  }
}

/// Emerald success banner shown right after finishing a session (`fromFinish`).
class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gap),
      decoration: BoxDecoration(
        color: gb.emeraldSoft,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: gb.emerald.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: gb.emerald,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gb.emerald.withValues(alpha: 0.55),
                  blurRadius: 12,
                  spreadRadius: -3,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.check,
                size: AppSizes.iconXxl, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nice work!',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    color: gb.emeraldInk),
              ),
              const SizedBox(height: 1),
              Text(
                'Session saved to your log.',
                style: TextStyle(
                    fontSize: 13, color: gb.emeraldInk.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseBreakdown extends StatelessWidget {
  const _ExerciseBreakdown(
      {required this.exercise, required this.isPr, required this.order});
  final PerformedExercise exercise;
  final bool isPr;
  final int order;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final skipped = exercise.status == ExercisePerformStatus.skipped;
    final vol = exercise.sets
        .fold<double>(0, (a, s) => a + (s.weightKg ?? 0) * (s.reps ?? 0));

    // Best estimated 1RM across the exercise's sets — prefer the server value, fall back to Epley.
    var best = 0.0;
    for (final s in exercise.sets) {
      final e1 = s.estimatedOneRepMaxKg ?? epleyOneRepMax(s.weightKg, s.reps);
      if (e1 != null && e1 > best) best = e1;
    }
    // Progress vs the previous session's top set for this lift (null when there's no prior reference).
    final prog = liftProgress(exercise);

    final metaParts = <String>[
      '${exercise.sets.length} set${exercise.sets.length == 1 ? '' : 's'}',
      // Volume / e1RM only mean something for weighted sets — hide them for cardio/timed/etc.
      if (vol > 0) '${_fmtVolume(vol)} kg',
      if (best > 0) 'e1RM ${best.toStringAsFixed(0)}kg',
    ];

    // Collapsed by default: the header alone (number · name · set/volume summary) tells the story, so a
    // long session stays scannable; tap to reveal the per-set pills.
    return GbCollapsibleCard(
      trailing: [
        if (isPr) const PrChip(small: true),
        if (skipped)
          GbStatusBadge(
              label: 'Skipped', background: gb.grey25, foreground: gb.grey600),
      ],
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GbOrderBadge(order),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.exerciseName ?? 'Exercise',
                    style: AppText.rowTitle.copyWith(color: gb.grey900)),
                const SizedBox(height: 1),
                Text(metaParts.join(' · '),
                    style: AppText.meta.copyWith(color: gb.grey500)),
                if (prog != null) ...[
                  const SizedBox(height: 3),
                  _VsLastDelta(prog: prog),
                ],
              ],
            ),
          ),
          GuideButton(
              exerciseId: exercise.exerciseId,
              name: exercise.exerciseName ?? 'Exercise'),
        ],
      ),
      child: exercise.sets.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final (i, s) in exercise.sets.indexed)
                  GbSetPill(label: performedSetChip(s, i + 1), isPr: s.isPr),
              ],
            ),
    );
  }
}

/// kg with a `1.2k` shorthand past a thousand — mirrors the prototype's `fmtVolume`.
String _fmtVolume(double kg) =>
    kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)}k' : kg.toStringAsFixed(0);

String _fmtDistanceValue(int m) =>
    m >= 1000 ? (m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1) : '$m';
String _fmtDistanceUnit(int m) => m >= 1000 ? 'km' : 'm';

/// Working sets per primary muscle group as labelled horizontal bars (scaled to the busiest group).
/// Session progress vs the previous session — a tinted strip summarising how many lifts beat / matched
/// / fell short of last time. Emerald when net-positive, amber otherwise.
class _ProgressVsLast extends StatelessWidget {
  const _ProgressVsLast({required this.progress});
  final ({int up, int down, int same, int compared}) progress;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final p = progress;
    final positive = p.up >= p.down;
    final fg = positive ? gb.emeraldInk : gb.amberInk;
    final bg = positive ? gb.emeraldSoft : gb.amberSoft;
    final parts = <String>[
      if (p.up > 0) '${p.up} up',
      if (p.same > 0) '${p.same} matched',
      if (p.down > 0) '${p.down} down',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: fg.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 18,
              color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: gb.grey700),
                children: [
                  TextSpan(
                      text: 'vs last time  ',
                      style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
                  TextSpan(
                      text:
                          '${parts.join(' · ')}  (of ${p.compared} lift${p.compared == 1 ? '' : 's'})'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Working sets per muscle group as labelled two-tone bars — solid = primary mover, lighter = secondary
/// (assisting) involvement. Scaled to the busiest group's total. Tap a row to reveal the exact
/// primary/secondary split.
class _MuscleBars extends StatefulWidget {
  const _MuscleBars(
      {required this.byMuscle, required this.breakdown, this.compact = false});
  final Map<String, MuscleInvolvement> byMuscle;

  /// Per-group contributing exercises (working sets + primary/secondary role) — shown when expanded.
  final Map<String, List<MuscleExerciseContribution>> breakdown;

  /// Overview = bars only (no tap/caret/breakdown). The (i) detail sheet (false) keeps tap-to-expand.
  final bool compact;

  @override
  State<_MuscleBars> createState() => _MuscleBarsState();
}

class _MuscleBarsState extends State<_MuscleBars> {
  final _expanded = <String>{};
  // The (i) detail sheet (compact=false) opens with only the FIRST (busiest) group expanded — the rest stay
  // collapsed so the sheet isn't a wall of rows. Done once, then the user controls it. The overview
  // (compact=true) stays fully collapsed.
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // The chart counts EXERCISES per muscle group — distinct lifts where the group was a primary mover
    // vs a secondary (assisting) one — not sets. Derived from the breakdown (deduped by exercise, so a
    // lift that hits a group both ways counts once, as primary). Sets stay visible as a muted number.
    final rows = <({
      String group,
      List<({String exerciseId, String name, int sets, bool isPrimary})> contribs,
      int primaryEx,
      int secondaryEx,
      int sets,
    })>[];
    for (final e in widget.byMuscle.entries) {
      final seen =
          <String, ({String exerciseId, String name, int sets, bool isPrimary})>{};
      for (final c in (widget.breakdown[e.key] ??
          const <MuscleExerciseContribution>[])) {
        final prev = seen[c.exerciseId];
        seen[c.exerciseId] = (
          exerciseId: c.exerciseId,
          name: c.name,
          sets: c.sets,
          isPrimary: (prev?.isPrimary ?? false) || c.isPrimary,
        );
      }
      final contribs = seen.values.toList()
        ..sort((a, b) {
          if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
          return b.sets.compareTo(a.sets);
        });
      rows.add((
        group: e.key,
        contribs: contribs,
        primaryEx: contribs.where((c) => c.isPrimary).length,
        secondaryEx: contribs.where((c) => !c.isPrimary).length,
        sets: e.value.total,
      ));
    }
    // Order by exercise coverage (what the bars now show); sets break ties to stay stable.
    rows.sort((a, b) {
      final byEx =
          (b.primaryEx + b.secondaryEx).compareTo(a.primaryEx + a.secondaryEx);
      return byEx != 0 ? byEx : b.sets.compareTo(a.sets);
    });
    final maxEx = rows.fold<int>(1, (a, r) {
      final n = r.primaryEx + r.secondaryEx;
      return n > a ? n : a;
    });
    // First open only the busiest group (the top row); the rest stay collapsed until tapped.
    if (!_initialized) {
      _initialized = true;
      if (!widget.compact && rows.isNotEmpty) _expanded.add(rows.first.group);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows) ...[
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: widget.compact
                ? null
                : () => setState(() => _expanded.contains(r.group)
                    ? _expanded.remove(r.group)
                    : _expanded.add(r.group)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(r.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: gb.grey700)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        // stretch → each segment fills the 8px height (a bare ColoredBox in a Row would
                        // otherwise collapse to 0px). Flex widths are proportional to the busiest group.
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (r.primaryEx > 0)
                              Expanded(
                                  flex: r.primaryEx,
                                  child: ColoredBox(color: gb.primary600)),
                            if (r.secondaryEx > 0)
                              Expanded(
                                  flex: r.secondaryEx,
                                  child: ColoredBox(
                                      color: gb.primary600
                                          .withValues(alpha: 0.30))),
                            if (maxEx - (r.primaryEx + r.secondaryEx) > 0)
                              Expanded(
                                  flex: maxEx - (r.primaryEx + r.secondaryEx),
                                  child: ColoredBox(color: gb.grey25)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Exercise count (what the bar shows) with the set total kept beside it, muted.
                  SizedBox(
                    width: 46,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${r.primaryEx + r.secondaryEx}',
                            style: AppText.mono(const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700))
                                .copyWith(color: gb.grey700)),
                        Text('${r.sets} ${r.sets == 1 ? 'set' : 'sets'}',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 10, color: gb.grey400)),
                      ],
                    ),
                  ),
                  // A quiet caret hinting the row expands to the split (overview hides it).
                  if (!widget.compact)
                    Icon(
                        _expanded.contains(r.group)
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: gb.grey400),
                ],
              ),
            ),
          ),
          // Tapped → the primary/secondary split AND which exercises drove this muscle's sets.
          if (!widget.compact && _expanded.contains(r.group))
            Padding(
              padding: const EdgeInsets.only(left: 84, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LegendDot(
                          color: gb.primary600,
                          label: '${r.primaryEx} primary'),
                      if (r.secondaryEx > 0) ...[
                        const SizedBox(width: AppSpacing.md),
                        _LegendDot(
                            color: gb.primary600.withValues(alpha: 0.30),
                            label: '${r.secondaryEx} secondary'),
                      ],
                    ],
                  ),
                  // The contributing exercises: a primary/secondary dot, the name, and its working sets.
                  for (final c in r.contribs)
                    // Tap a contributing lift to see ITS own muscle map (just that exercise).
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () =>
                          _showExerciseMap(context, c.exerciseId, c.name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c.isPrimary
                                    ? gb.primary600
                                    : gb.primary600.withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5, color: gb.grey700)),
                            ),
                            const SizedBox(width: 8),
                            Text('${c.sets} ${c.sets == 1 ? 'set' : 'sets'}',
                                style: AppText.mono(
                                        const TextStyle(fontSize: 11.5))
                                    .copyWith(color: gb.grey500)),
                            const SizedBox(width: 3),
                            Icon(Icons.chevron_right,
                                size: 15, color: gb.grey400),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xs),
        // Legend so the two tones read clearly.
        Row(
          children: [
            _LegendDot(color: gb.primary600, label: 'Primary'),
            const SizedBox(width: AppSpacing.md),
            _LegendDot(
                color: gb.primary600.withValues(alpha: 0.30),
                label: 'Secondary'),
          ],
        ),
      ],
    );
  }
}

/// The full Muscles-trained breakdown in a bottom sheet (opened from the overview's (i)) — the same
/// two-tone bars, but tap a group to reveal its primary/secondary split and the exercises behind it.
void _showMuscleDetail(
  BuildContext context,
  Map<String, MuscleInvolvement> byMuscle,
  Map<String, List<MuscleExerciseContribution>> breakdown,
  String muscleMapKey,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gb.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          const GbSheetHeader(
            title: 'Muscles trained',
            subtitle:
                'Exercises per muscle — tap a group for the lifts and sets behind it.',
          ),
          const SizedBox(height: AppSpacing.md),
          // Whole-session body heat-map with per-group on/off toggles (filters which muscles light up).
          _SessionMuscleMap(
              muscleMapKey: muscleMapKey, groups: byMuscle.keys.toList()),
          _MuscleBars(byMuscle: byMuscle, breakdown: breakdown),
        ],
      ),
    ),
  );
}

/// The whole-session body heat-map plus per-muscle-group on/off chips. Every group starts on (the full
/// session view); toggling a group off greys its muscles on the figure so you can isolate regions. The
/// bars below stay complete — this only filters the picture.
class _SessionMuscleMap extends ConsumerStatefulWidget {
  const _SessionMuscleMap({required this.muscleMapKey, required this.groups});
  final String muscleMapKey;
  final List<String> groups;
  @override
  ConsumerState<_SessionMuscleMap> createState() => _SessionMuscleMapState();
}

class _SessionMuscleMapState extends ConsumerState<_SessionMuscleMap> {
  late final Set<String> _enabled = {...widget.groups};

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return ref.watch(_sessionMuscleMapProvider(widget.muscleMapKey)).when(
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (m) {
            // Nothing resolvable for the whole session → no map at all.
            if (!muscleMapHasContent(const [], const [],
                detailedPrimary: m.primary, detailedSecondary: m.secondary)) {
              return const SizedBox.shrink();
            }
            // All groups on = the full view (no filtering). Otherwise keep only slugs whose canonical muscle
            // belongs to an enabled group.
            final allOn = _enabled.length == widget.groups.length;
            final allowed = <String>{
              for (final g in _enabled) ...groupFineMuscles(g)
            };
            bool keep(String s) {
              final c = canonicalMuscle(s);
              return c != null && allowed.contains(c);
            }

            final primary = allOn ? m.primary : m.primary.where(keep).toList();
            final secondary =
                allOn ? m.secondary : m.secondary.where(keep).toList();
            final hasShown = muscleMapHasContent(const [], const [],
                detailedPrimary: primary, detailedSecondary: secondary);
            return Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: gb.grey0,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SizedBox(
                    height: 200,
                    child: hasShown
                        ? MuscleMapFigure(
                            exerciseName: '',
                            primary: const [],
                            secondary: const [],
                            detailedPrimary: primary,
                            detailedSecondary: secondary,
                          )
                        : Center(
                            child: Text('No muscle group selected',
                                style: TextStyle(
                                    fontSize: 13, color: gb.grey500))),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Group on/off chips — tap to isolate which groups light the figure.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final g in widget.groups)
                      _groupToggleChip(
                        context,
                        g,
                        _enabled.contains(g),
                        () => setState(() => _enabled.contains(g)
                            ? _enabled.remove(g)
                            : _enabled.add(g)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          },
        );
  }
}

/// A single exercise's muscle map in a compact sheet — opened by tapping a lift inside the Muscles-trained
/// breakdown. Reuses [MuscleMapFigure] with that exercise's own (detailed + coarse) muscles.
void _showExerciseMap(BuildContext context, String exerciseId, String name) {
  showDialog<void>(
    context: context,
    builder: (dctx) {
      final gb = dctx.gb;
      return Dialog(
        backgroundColor: gb.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: exercise name + a close affordance (the barrier also dismisses).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: gb.ink)),
                        const SizedBox(height: 1),
                        Text('Muscles worked',
                            style: TextStyle(fontSize: 13, color: gb.grey500)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dctx).pop(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.close, size: 20, color: gb.grey400),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Consumer(builder: (ctx, ref, _) {
                return ref.watch(_exerciseDetailProvider(exerciseId)).when(
                      loading: () => const SizedBox(
                          height: 200,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2))),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (d) {
                        if (d == null) return const SizedBox.shrink();
                        final primary =
                            d.primaryMuscles.map((m) => m.name).toList();
                        final secondary =
                            d.secondaryMuscles.map((m) => m.name).toList();
                        if (!muscleMapHasContent(primary, secondary,
                            detailedPrimary: d.detailedPrimaryMuscles,
                            detailedSecondary: d.detailedSecondaryMuscles)) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('No muscle map for this exercise.',
                                style: TextStyle(color: gb.grey500)),
                          );
                        }
                        // Name the worked muscles as chips — detailed slugs when the catalog has them, else
                        // the coarse groups. Main mover = solid-red dot, secondary = light-red (the figure's
                        // palette).
                        final primaryChips =
                            d.detailedPrimaryMuscles.isNotEmpty
                                ? d.detailedPrimaryMuscles
                                : primary;
                        final secondaryChips =
                            d.detailedSecondaryMuscles.isNotEmpty
                                ? d.detailedSecondaryMuscles
                                : secondary;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 220,
                              child: MuscleMapFigure(
                                exerciseName: d.name,
                                primary: primary,
                                secondary: secondary,
                                detailedPrimary: d.detailedPrimaryMuscles,
                                detailedSecondary: d.detailedSecondaryMuscles,
                              ),
                            ),
                            if (primaryChips.isNotEmpty ||
                                secondaryChips.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final mu in primaryChips)
                                    _muscleChip(ctx, _prettyMuscle(mu), true),
                                  for (final mu in secondaryChips)
                                    _muscleChip(ctx, _prettyMuscle(mu), false),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    );
              }),
            ],
          ),
        ),
      );
    },
  );
}

/// A muscle slug/name → a display label (e.g. 'upper-back' → 'Upper Back', 'forearm' → 'Forearm').
String _prettyMuscle(String s) => s
    .replaceAll(RegExp(r'[-_]'), ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// A compact, tappable group on/off chip for the session heat-map — sizes to its label (unlike GbChip,
/// which fills its row inside a Wrap), so several wrap neatly. Filled when on, muted-outline when off.
Widget _groupToggleChip(
    BuildContext context, String label, bool on, VoidCallback onTap) {
  final gb = context.gb;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: on ? gb.primary600 : gb.grey0,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: on ? gb.primary600 : gb.borderCard),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: on ? Colors.white : gb.grey600)),
    ),
  );
}

/// A worked-muscle chip for the per-exercise map dialog — a solid-red dot for the main mover, light-red
/// for a secondary one (matching the figure), with the muscle name.
Widget _muscleChip(BuildContext context, String label, bool primary) {
  final gb = context.gb;
  const primaryDot = Color(0xFFDC2626);
  const secondaryDot = Color(0xFFF87171);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: gb.grey0,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: gb.borderCard),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: primary ? primaryDot : secondaryDot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: gb.grey700)),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: context.gb.grey500)),
      ],
    );
  }
}

/// Per-exercise "vs last time" delta — this session's best working-set e1RM against the prior session's
/// top set. Emerald when up, amber when down, neutral when matched.
class _VsLastDelta extends StatelessWidget {
  const _VsLastDelta({required this.prog});
  final LiftProgress prog;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (Color c, String label) = prog.isUp
        ? (gb.emeraldInk, '↑ +${_fmtKgDelta(prog.deltaE1rmKg)} e1RM vs last')
        : prog.isDown
            ? (
                gb.amberInk,
                '↓ −${_fmtKgDelta(prog.deltaE1rmKg.abs())} e1RM vs last'
              )
            : (gb.grey500, '= matched last time');
    return Text(label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c));
  }
}

String _fmtKgDelta(double v) =>
    v % 1 == 0 ? '${v.toInt()}kg' : '${v.toStringAsFixed(1)}kg';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// `Monday, Jun 1` style date (local).
String _dateLabel(DateTime d, [String? zone]) {
  final l = AppTimeZone.wallClock(d, zone);
  return '${_fullWeekday(l.weekday)}, ${_months[l.month - 1]} ${l.day}';
}

String _fullWeekday(int weekday) => switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      _ => 'Sunday',
    };

/// `6:40pm` style time (local).
String _timeLabel(DateTime d, [String? zone]) {
  final l = AppTimeZone.wallClock(d, zone);
  final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  final ap = l.hour < 12 ? 'am' : 'pm';
  return '$h12:$m$ap';
}
