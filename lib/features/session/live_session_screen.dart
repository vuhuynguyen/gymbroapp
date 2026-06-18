import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/exercise_models.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../domain/enums.dart';
import '../../domain/exercise_tracking.dart';
import '../../domain/session_metrics.dart';
import '../../shared/superset/superset_grouping.dart';
import '../../shared/widgets/widgets.dart';
import '../progress/exercise_trend_sheet.dart';
import 'coach_guide.dart';
import 'live_session_controller.dart';

/// Full-screen Live Active Session — a faithful build of the design prototype (gradient focus header,
/// exercise card with meta pills, set rows, the highlighted current-set entry card with a set-type
/// selector + Epley e1RM, rest timer, finish/abandon). Server enforces the rules; this surfaces them.
class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

const _setTypeCycle = [
  PerformedSetType.warmup,
  PerformedSetType.working,
  PerformedSetType.drop,
  PerformedSetType.amrap,
];

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  String? _entryKey;
  // Mode-aware entry values keyed by metric (weight is a double, the rest ints).
  final Map<TrackingMetric, num> _entry = {};
  PerformedSetType _entryType = PerformedSetType.working;

  /// Reveals the secondary metric inputs (calories / heart rate / rest) for the current entry.
  bool _showMoreMetrics = false;

  num _val(TrackingMetric m) => _entry[m] ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveSessionControllerProvider.notifier).load(widget.sessionId);
    });
  }

  LiveSessionController get _ctrl =>
      ref.read(liveSessionControllerProvider.notifier);

  void _maybeSeedEntry(LiveSessionState st) {
    final ex = st.currentExercise;
    if (ex == null) return;
    final key = '${ex.id}:${ex.sets.length}';
    if (key == _entryKey) return;
    _entryKey = key;
    _showMoreMetrics = false;
    final snapSet = _snapshotSetFor(st, ex, ex.sets.length);
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;

    // Seed each metric from THIS set's plan prescription first, falling back to the last logged value
    // only when the plan doesn't prescribe it (e.g. ad-hoc sets logged beyond the plan). Preferring the
    // plan means each set shows what it's supposed to be — a 7-set plan walks through its escalating
    // warmups / working / drop targets instead of carrying the first set's value forward.
    _entry
      ..clear()
      ..[TrackingMetric.weight] = snapSet?.targetWeightKg ?? last?.weightKg ?? 0
      ..[TrackingMetric.reps] = snapSet?.targetReps ?? last?.reps ?? 0
      ..[TrackingMetric.duration] =
          snapSet?.targetDurationSeconds ?? last?.durationSeconds ?? 0
      ..[TrackingMetric.distance] =
          snapSet?.targetDistanceM ?? last?.distanceM ?? 0
      ..[TrackingMetric.rounds] = snapSet?.targetRounds ?? last?.rounds ?? 0
      ..[TrackingMetric.calories] = last?.calories ?? 0
      ..[TrackingMetric.heartRate] = last?.avgHeartRate ?? 0
      ..[TrackingMetric.incline] = last?.inclinePercent ?? 0
      ..[TrackingMetric.speed] = last?.speedKph ?? 0
      ..[TrackingMetric.level] = (last?.level ?? 0).toDouble()
      // 0 = auto-capture the actual rest from the timer; the user can bump it to override.
      ..[TrackingMetric.rest] = 0
      // RPE is the headline effort field — seed it from the plan's prescribed RPE (0 = let the user
      // enter it). Never carried from the last set, since effort is per-set.
      ..[TrackingMetric.rpe] = snapSet?.targetRpe ?? 0;
    _entryType = snapSet != null
        ? PerformedSetType.parse(snapSet.setType.wire)
        : (last?.setType ?? PerformedSetType.working);
  }

  SessionSnapshotSet? _snapshotSetFor(
      LiveSessionState st, PerformedExercise ex, int index) {
    final exs = st.session?.snapshot?.exercises;
    if (exs == null) return null;
    for (final se in exs) {
      if (se.exerciseId == ex.exerciseId && se.sets.length > index) {
        return se.sets[index];
      }
    }
    return null;
  }

  List<SessionSnapshotSet> _snapshotSetsFor(
      LiveSessionState st, PerformedExercise ex) {
    final exs = st.session?.snapshot?.exercises;
    if (exs == null) return const [];
    for (final se in exs) {
      if (se.exerciseId == ex.exerciseId) return se.sets;
    }
    return const [];
  }

  int? _plannedCount(LiveSessionState st, PerformedExercise ex) =>
      _snapshotSetsFor(st, ex).length;

  Future<void> _logSet(String exerciseId, ExerciseTrackingType type) async {
    // Only log the metrics this exercise's mode uses, so a Timed set never carries a stray reps/weight
    // (and a strength set never carries duration). Non-relevant fields are dropped to null.
    final profile = trackingProfileFor(type);
    final keep = {...profile.fields, ...profile.extras};
    int? gi(TrackingMetric m) =>
        keep.contains(m) && _val(m) > 0 ? _val(m).toInt() : null;
    double? gd(TrackingMetric m) =>
        keep.contains(m) && _val(m) > 0 ? _val(m).toDouble() : null;

    final values = SetMetricValues(
      reps: gi(TrackingMetric.reps),
      weightKg: gd(TrackingMetric.weight),
      durationSeconds: gi(TrackingMetric.duration),
      distanceM: gi(TrackingMetric.distance),
      rounds: gi(TrackingMetric.rounds),
    );
    // Mode-aware required-metric check (mirrors the server): strength needs reps, cardio
    // duration/distance, HIIT rounds/duration; mobility accepts a marked-done set.
    if (!hasRequiredMetric(type, values)) {
      showInfoSnack(context, requiredMetricMessage(type));
      return;
    }
    final rest = keep.contains(TrackingMetric.rest)
        ? _val(TrackingMetric.rest).toInt()
        : 0;
    // RPE applies to every mode (it's universal perceived effort, not a mode-specific metric), so it's
    // read directly rather than gated by the profile's field list. 0 = not entered → omitted.
    final rpe = _val(TrackingMetric.rpe).toInt();
    await _ctrl.logSet(
      exerciseId,
      reps: values.reps,
      weightKg: values.weightKg,
      rpe: rpe > 0 ? rpe : null,
      setType: _entryType,
      durationSeconds: values.durationSeconds,
      distanceM: values.distanceM,
      rounds: values.rounds,
      calories: gi(TrackingMetric.calories),
      avgHeartRate: gi(TrackingMetric.heartRate),
      inclinePercent: gd(TrackingMetric.incline),
      speedKph: gd(TrackingMetric.speed),
      level: gi(TrackingMetric.level),
      // 0 → let the controller auto-capture the actual rest taken from the timer; >0 overrides it.
      restSeconds: rest > 0 ? rest : null,
    );
  }

  /// Confirms and deletes a logged set. Returns true if the set was removed
  /// (so swipe-to-delete can animate the row out only on actual deletion).
  Future<bool> _confirmDeleteSet(String exerciseId, PerformedSet set) async {
    final ok = await showGbSheet<bool>(
      context,
      builder: (ctx) => const _ConfirmSheet(
        icon: Icons.delete_outline,
        title: 'Delete this set?',
        message: 'This removes the logged set from your session.',
        confirmLabel: 'Delete set',
        cancelLabel: 'Cancel',
      ),
    );
    if (ok == true) {
      await _ctrl.deleteSet(exerciseId, set.id);
      return true;
    }
    return false;
  }

  /// Opens the edit sheet for an already-logged set and applies the change via the controller.
  Future<void> _editSet(
      String exerciseId, PerformedSet set, ExerciseTrackingType type) async {
    await showGbSheet<void>(
      context,
      builder: (ctx) => _EditSetSheet(
        set: set,
        trackingType: type,
        onSave: (req) async {
          await _ctrl.editSet(exerciseId, set.id, req);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onDelete: () async {
          await _ctrl.deleteSet(exerciseId, set.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _confirmAbandon() async {
    final st = ref.read(liveSessionControllerProvider);
    final logged = countLoggedSets(st.exercises);
    final total = st.session?.snapshot?.exercises
            .fold<int>(0, (a, e) => a + e.sets.length) ??
        logged;
    final ok = await showGbSheet<bool>(
      context,
      builder: (ctx) => _ConfirmSheet(
        icon: Icons.flag_outlined,
        title: 'Abandon session?',
        message:
            "You've logged $logged of ${total > logged ? total : logged} sets. "
            "The session will be saved as abandoned and you can't resume it.",
        confirmLabel: 'Abandon session',
        cancelLabel: 'Keep training',
      ),
    );
    if (ok == true) {
      final done = await _ctrl.abandon();
      if (done && mounted) context.go('/log');
    }
  }

  Future<void> _finish() async {
    final st = ref.read(liveSessionControllerProvider);
    final id = st.session?.sessionId;
    // Nothing logged → there's no workout to complete; save it as abandoned instead.
    final hasAnySet = st.exercises.any((e) => e.sets.isNotEmpty);
    if (!hasAnySet) {
      final done = await _ctrl.abandon();
      if (done && mounted) {
        showInfoSnack(context, 'Nothing logged — session discarded.');
        context.go('/log');
      }
      return;
    }
    final done = await _ctrl.complete();
    if (done && mounted && id != null) {
      context.pushReplacement('/session-detail/$id?finished=true&me=1');
    }
  }

  /// Editing a finished workout: edits are already saved per-mutation, so "Done" just refreshes the
  /// history/detail and leaves — no complete/abandon.
  void _done() {
    _ctrl.doneEditing();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/log');
    }
  }

  void _openExerciseMenu(PerformedExercise ex) {
    final hasLogged = ex.sets.isNotEmpty;
    showGbSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs, AppSpacing.xxs, 0, AppSpacing.xs),
              child: Text(ex.exerciseName ?? 'Exercise ${ex.order}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            GbSheetActionTile(
              icon: Icons.swap_horiz,
              label: 'Substitute exercise',
              sub: 'Swap for an equivalent movement',
              onTap: () {
                Navigator.of(ctx).pop();
                _openCatalog(
                    title: 'Substitute',
                    onPick: (e) => _ctrl.substituteExercise(ex.id, e.id));
              },
            ),
            GbSheetActionTile(
              icon: Icons.skip_next,
              label: 'Skip exercise',
              sub: hasLogged
                  ? 'Has logged sets — can’t skip'
                  : 'Mark this exercise as skipped',
              onTap: hasLogged
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _ctrl.skipExercise(ex.id);
                    },
            ),
            GbSheetActionTile(
              icon: Icons.delete_outline,
              iconColor: context.gb.danger,
              label: 'Remove exercise',
              sub: hasLogged
                  ? 'Removes it and deletes its logged sets'
                  : 'Take it out of this workout',
              onTap: () {
                Navigator.of(ctx).pop();
                _ctrl.removeExercise(ex.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openGuideSheet(PerformedExercise ex, ExerciseSummary? catalog) {
    presentGuideSheet(
      context,
      _GuideSheet(
        exerciseId: ex.exerciseId,
        exerciseName: ex.exerciseName ?? catalog?.name ?? 'Exercise',
        catalog: catalog,
        repository: ref.read(exerciseRepositoryProvider),
      ),
    );
  }

  void _openCatalog(
      {required String title, required ValueChanged<ExerciseSummary> onPick}) {
    showGbSheet<void>(
      context,
      scrollable: true,
      builder: (ctx) => _CatalogSheet(
        title: title,
        onPick: (e) {
          Navigator.of(ctx).pop();
          onPick(e);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveSessionControllerProvider.select((s) => s.errorMessage),
        (_, msg) {
      if (msg != null) {
        showInfoSnack(context, msg);
        _ctrl.clearError();
      }
    });

    final st = ref.watch(liveSessionControllerProvider);
    final catalog = ref.watch(exerciseCatalogProvider).valueOrNull ??
        const <String, ExerciseSummary>{};
    // Today's recovery/fuel signals for the pre-log set suggestion (fields degrade to null if absent).
    final wellness = ref.watch(wellnessSignalsProvider);

    if (st.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (st.session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.fitness_center,
          title: 'No active workout',
          subtitle: st.errorMessage ?? 'Start a workout from the Log tab.',
          action: FilledButton(
              onPressed: () => context.go('/log'),
              child: const Text('Back to Log')),
        ),
      );
    }

    _maybeSeedEntry(st);
    final session = st.session!;
    // Editing a finished workout in place (status != InProgress): no rest timer, "Done" instead of
    // "Finish", and the header reads "Editing logged workout".
    final editing = !session.status.isInProgress;
    // Ad-hoc sessions start with NO exercises — `currentExercise` is null until one is added, so
    // never null-assert it here (the 1s elapsed timer rebuilds every tick).
    final ex = st.currentExercise;
    final logged = countLoggedSets(session.exercises);
    final totalPlanned =
        session.snapshot?.exercises.fold<int>(0, (a, e) => a + e.sets.length) ??
            0;
    final total = totalPlanned > logged ? totalPlanned : logged;
    final exIndex =
        ex == null ? -1 : session.exercises.indexWhere((e) => e.id == ex.id);
    // Superset rotation cue for the current exercise (null when standalone / not in a 2+ group).
    final supersetTag = ex == null
        ? null
        : supersetTags([
            for (final e in session.exercises)
              SupersetMember(
                  id: e.id,
                  order: e.order,
                  groupId: e.supersetGroupId,
                  name: e.exerciseName),
          ])[ex.id];

    return Scaffold(
      body: Column(
        children: [
          _Header(
            topInset: MediaQuery.of(context).padding.top,
            title: session.snapshot?.workoutName ?? 'Workout',
            subtitle: editing
                ? 'Editing logged workout'
                : (session.source == SessionSource.fromAssignment
                    ? 'Plan workout'
                    : 'Ad-hoc session'),
            logged: logged,
            total: total,
            hasTarget: totalPlanned > 0,
            // Editing a finished workout: no "abandon" — leaving via back/Done just saves the edits.
            onAbandon: editing ? null : _confirmAbandon,
            onBack: () => context.canPop() ? context.pop() : context.go('/log'),
          ),
          _ExercisePager(
            elapsed: st.elapsedSeconds,
            exercises: session.exercises,
            currentId: ex?.id ?? '',
            plannedCountFor: (e) => _plannedCount(st, e),
            onSelect: _ctrl.setCurrentExercise,
            onAdd: () => _openCatalog(
                title: 'Add exercise', onPick: (e) => _ctrl.addExercise(e.id)),
          ),
          Expanded(
            child: ex == null
                ? EmptyState(
                    icon: Icons.add_circle_outline,
                    title: 'No exercises yet',
                    subtitle:
                        'Tap + to add your first exercise to this session.',
                    tapLabel: 'Add exercise',
                    onTap: () => _openCatalog(
                        title: 'Add exercise',
                        onPick: (e) => _ctrl.addExercise(e.id)),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _ExerciseCard(
                        exercise: ex,
                        supersetTag: supersetTag,
                        catalog: catalog[ex.exerciseId],
                        snapshotSets: _snapshotSetsFor(st, ex),
                        profile: trackingProfileFor(ex.trackingType),
                        entry: _entry,
                        entryType: _entryType,
                        busy: st.busy,
                        canLog: hasRequiredMetric(
                          ex.trackingType,
                          SetMetricValues(
                            reps: _val(TrackingMetric.reps).toInt(),
                            weightKg: _val(TrackingMetric.weight).toDouble(),
                            durationSeconds:
                                _val(TrackingMetric.duration).toInt(),
                            distanceM: _val(TrackingMetric.distance).toInt(),
                            rounds: _val(TrackingMetric.rounds).toInt(),
                          ),
                        ),
                        showMore: _showMoreMetrics,
                        onToggleMore: () => setState(
                            () => _showMoreMetrics = !_showMoreMetrics),
                        onMetric: (m, v) => setState(() => _entry[m] = v),
                        onSetType: (t) => setState(() => _entryType = t),
                        onLog: () => _logSet(ex.id, ex.trackingType),
                        onDeleteSet: (s) => _confirmDeleteSet(ex.id, s),
                        // returns Future<bool>: true when the set was deleted
                        onEditSet: (s) => _editSet(ex.id, s, ex.trackingType),
                        onMoveSet: (s, up) =>
                            _ctrl.moveSet(ex.id, s.id, up: up),
                        onMenu: () => _openExerciseMenu(ex),
                        onGuide: () =>
                            _openGuideSheet(ex, catalog[ex.exerciseId]),
                        onTrend: () => showExerciseTrendSheet(
                          context,
                          exerciseId: ex.exerciseId,
                          exerciseName: ex.exerciseName ??
                              catalog[ex.exerciseId]?.name ??
                              'Exercise',
                        ),
                        wellness: wellness,
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      Center(
                        child: Text(
                            'Tap a set to edit · arrows reorder · swipe to delete',
                            textAlign: TextAlign.center,
                            style: AppText.meta
                                .copyWith(color: context.gb.grey400)),
                      ),
                    ],
                  ),
          ),
          if (!editing && st.rest != null)
            _RestBar(
                rest: st.rest!,
                onAdd: () => _ctrl.adjustRest(15),
                onSkip: _ctrl.skipRest),
          SafeArea(
            top: false,
            child: _ActionBar(
              canPrev: exIndex > 0,
              isLast: exIndex == session.exercises.length - 1,
              busy: st.busy,
              editing: editing,
              onPrev: () {
                if (exIndex > 0) {
                  _ctrl.setCurrentExercise(session.exercises[exIndex - 1].id);
                }
              },
              onNext: () {
                if (exIndex < session.exercises.length - 1) {
                  _ctrl.setCurrentExercise(session.exercises[exIndex + 1].id);
                }
              },
              onFinish: editing ? _done : _finish,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.topInset,
    required this.title,
    required this.subtitle,
    required this.logged,
    required this.total,
    required this.hasTarget,
    required this.onAbandon,
    required this.onBack,
  });
  final double topInset;
  final String title;
  final String subtitle;
  final int logged;
  final int total;

  /// True only for plan sessions with a planned set target — drives the progress bar and the
  /// "logged/total" count. Ad-hoc sessions have no target, so they show a bare "N sets" instead.
  final bool hasTarget;

  /// Null when editing a finished workout — there's nothing to abandon, so the X is hidden.
  final VoidCallback? onAbandon;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pct = hasTarget && total > 0 ? (logged / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      decoration: const BoxDecoration(gradient: GbColors.heroGradient),
      // Tight padding so the blue header matches a standard detail header's height (the progress bar
      // below is the only extra, slimmed to a thin accent).
      padding: EdgeInsets.fromLTRB(8, topInset + 2, 8, AppSpacing.xs),
      child: Column(
        children: [
          // Top row: back · centred title · abandon. Symmetric glass buttons keep the title centred.
          Row(
            children: [
              GbGlassButton(
                  icon: Icons.chevron_left,
                  onTap: onBack,
                  semanticLabel: 'Back to app'),
              Expanded(
                child: Column(
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11)),
                  ],
                ),
              ),
              if (onAbandon != null)
                GbGlassButton(
                    icon: Icons.close,
                    onTap: onAbandon!,
                    semanticLabel: 'Abandon workout')
              else
                const SizedBox(
                    width: 40), // keep the title centred when editing
            ],
          ),
          // Plan-only progress bar (full width). The elapsed timer moved to the exercise-pager row to
          // save vertical space, so ad-hoc sessions now get a compact single-row header.
          if (hasTarget) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 5,
                width: double.infinity,
                child: Stack(
                  children: [
                    const ColoredBox(color: Colors.white24),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: pct,
                      child: const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: GbColors.progressFill),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExercisePager extends StatelessWidget {
  const _ExercisePager({
    required this.exercises,
    required this.currentId,
    required this.plannedCountFor,
    required this.onSelect,
    required this.onAdd,
    required this.elapsed,
  });
  final int elapsed;
  final List<PerformedExercise> exercises;
  final String currentId;
  final int? Function(PerformedExercise) plannedCountFor;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: context.gb.borderCard)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            // Scrollable exercise chips take the remaining width; the timer stays pinned right.
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (var i = 0; i < exercises.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PagerChip(
                        number: i + 1,
                        current: exercises[i].id == currentId,
                        done: isPerformedExerciseComplete(
                            exercises[i], plannedCountFor(exercises[i])),
                        skipped: exercises[i].status ==
                            ExercisePerformStatus.skipped,
                        onTap: () => onSelect(exercises[i].id),
                      ),
                    ),
                  GbDashedPill(
                    onTap: onAdd,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Live elapsed timer — pinned to the right of the pager so it stays visible while the
            // exercise chips scroll. Moved off the header to save a row of vertical space.
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: _PagerTimer(elapsed: elapsed),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live elapsed-time pill that rides the exercise-pager row (white surface), replacing the timer
/// that used to live in the gradient header. Neutral grey so it reads as ambient info, not as an
/// interactive chip — the clock icon + tabular `mm:ss` carry the meaning.
class _PagerTimer extends StatelessWidget {
  const _PagerTimer({required this.elapsed});
  final int elapsed;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: gb.grey0,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: gb.borderField),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: gb.grey500),
          const SizedBox(width: 5),
          Text(formatDuration(elapsed),
              style: TextStyle(
                  color: gb.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _PagerChip extends StatelessWidget {
  const _PagerChip({
    required this.number,
    required this.current,
    required this.done,
    required this.skipped,
    required this.onTap,
  });
  final int number;
  final bool current;
  final bool done;
  final bool skipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final Color bg, border, fg;
    if (current) {
      bg = gb.primary500;
      border = gb.primary500;
      fg = Colors.white;
    } else if (done) {
      bg = gb.success0;
      border = gb.success.withValues(alpha: 0.4);
      fg = gb.success;
    } else {
      bg = Colors.white;
      border = gb.borderCard;
      fg = gb.grey500;
    }
    final marker =
        skipped ? Icons.remove : (done && !current ? Icons.check : null);
    final label = Text('$number',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg));
    // A number on its own is a circle (design step indicator); a marker + number stays a pill.
    final shape = marker != null
        ? StadiumBorder(side: BorderSide(color: border, width: 1.5))
        : CircleBorder(side: BorderSide(color: border, width: 1.5));
    return Material(
      color: bg,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: marker != null
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(marker, size: 13, color: fg),
                    const SizedBox(width: 4),
                    label
                  ],
                ),
              )
            : SizedBox(width: 30, height: 30, child: Center(child: label)),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    this.supersetTag,
    required this.catalog,
    required this.snapshotSets,
    required this.profile,
    required this.entry,
    required this.entryType,
    required this.busy,
    required this.canLog,
    required this.showMore,
    required this.onToggleMore,
    required this.onMetric,
    required this.onSetType,
    required this.onLog,
    required this.onDeleteSet,
    required this.onEditSet,
    required this.onMoveSet,
    required this.onMenu,
    required this.onGuide,
    required this.onTrend,
    required this.wellness,
  });

  final PerformedExercise exercise;

  /// Superset membership for this exercise (A1/A2 …), or null when standalone — drives the rotation cue.
  final SupersetTag? supersetTag;
  final ExerciseSummary? catalog;
  final List<SessionSnapshotSet> snapshotSets;
  final TrackingProfile profile;
  final Map<TrackingMetric, num> entry;
  final PerformedSetType entryType;
  final bool busy;
  final bool canLog;
  final bool showMore;
  final VoidCallback onToggleMore;
  final void Function(TrackingMetric, num) onMetric;
  final ValueChanged<PerformedSetType> onSetType;
  final VoidCallback onLog;
  final Future<bool> Function(PerformedSet) onDeleteSet;

  /// Opens the edit sheet for a logged set.
  final void Function(PerformedSet) onEditSet;

  /// Reorders a logged lead set one slot up ([up] = true) or down.
  final void Function(PerformedSet set, bool up) onMoveSet;
  final VoidCallback onMenu;
  final VoidCallback onGuide;

  /// Opens the per-exercise trend sheet (the trend (i) button in the card header).
  final VoidCallback onTrend;

  /// Today's recovery/fuel signals — used to gently autoregulate the suggested next set.
  final WellnessSignals wellness;

  /// Lead (parentless) sets — the rows that carry a reorder position; drop stages ride with their lead.
  List<PerformedSet> get _leads =>
      exercise.sets.where((s) => s.parentSetId == null).toList();
  int get _leadCount => _leads.length;

  /// Position of [s] among the lead sets, or -1 if it's a drop stage (not independently movable).
  int _leadIndex(PerformedSet s) =>
      s.parentSetId != null ? -1 : _leads.indexWhere((l) => l.id == s.id);

  /// "Last time" pill: the trainee's most recent PRIOR performance of this lift (from a previous completed
  /// session — never the set just logged), with how long ago. Falls back to the plan's first prescribed
  /// target while no history exists and nothing's been logged yet. Null when neither is available.
  String? _metaTargets() {
    final lp = exercise.lastPerformed;
    if (lp != null && (lp.weightKg ?? 0) > 0 && (lp.reps ?? 0) > 0) {
      final w = lp.weightKg!;
      final ago = lastPerformedAgo(lp.performedAt);
      return 'Last ${w % 1 == 0 ? w.toInt() : w}kg × ${lp.reps}'
          '${ago.isEmpty ? '' : ' · $ago'}';
    }
    // No prior history: show the plan's first prescribed target until the user starts logging.
    if (exercise.sets.isNotEmpty || snapshotSets.isEmpty) return null;
    final t = snapshotSets.first;
    final parts = <String>[];
    final w = t.targetWeightKg ?? 0;
    final r = t.targetReps ?? 0;
    if (w > 0 && r > 0) {
      parts.add('${w % 1 == 0 ? w.toInt() : w}kg × $r');
    } else if (r > 0) {
      parts.add('$r reps');
    }
    if ((t.targetDurationSeconds ?? 0) > 0)
      parts.add(formatDuration(t.targetDurationSeconds!));
    if ((t.targetDistanceM ?? 0) > 0) parts.add('${t.targetDistanceM}m');
    if ((t.targetRounds ?? 0) > 0) parts.add('${t.targetRounds} rounds');
    return parts.isEmpty ? null : 'Target ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final name = exercise.exerciseName ?? 'Exercise ${exercise.order}';
    final isSkipped = exercise.status == ExercisePerformStatus.skipped;
    final targets = _metaTargets();
    // The plan prescription for the set about to be logged (null past the plan / ad-hoc), and the
    // pre-log weight × reps suggestion derived from it + last-time + today's readiness.
    final entryTarget = snapshotSets.length >= exercise.sets.length + 1
        ? snapshotSets[exercise.sets.length]
        : null;
    final suggestion = suggestNextSet(
      trackingType: exercise.trackingType,
      setType: entryType,
      target: entryTarget,
      lastPerformed: exercise.lastPerformed,
      wellness: wellness,
    );
    // Per-exercise set count (logged vs planned). Count EVERY logged set incl. drop stages, so it matches
    // the prescription walk below (which indexes prescribed sets by total logged count) and the rows shown —
    // otherwise a plan with prescribed drop sets sticks at e.g. "4/7" and never completes.
    final loggedCount = exercise.sets.length;
    final plannedCount = snapshotSets.length;
    final setsLabel = plannedCount > 0
        ? '$loggedCount/$plannedCount sets'
        : '$loggedCount ${loggedCount == 1 ? 'set' : 'sets'}';
    final pills = <String>[
      setsLabel,
      if (catalog?.muscleGroup.isNotEmpty ?? false) catalog!.muscleGroup,
      if (catalog?.equipment.isNotEmpty ?? false) catalog!.equipment,
      if (targets != null) targets,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: gb.borderCard),
        boxShadow: gb.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — title + meta pills, the more-options button, and (inset, below the pills) the
          // always-visible form-cue strip. The strip sits inside the 16px header padding, matching
          // the design (a rounded tinted bar with left/right margin, not a full-bleed row).
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                          if (exercise.substitutedFromExerciseName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                  'Substituted from ${exercise.substitutedFromExerciseName}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                          if (pills.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(spacing: 8, runSpacing: 6, children: [
                                for (final p in pills) GbMetaPill(p)
                              ]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Trend (i) — peek at this exercise's strength trend without leaving the workout.
                    GbIconButton(
                        icon: Icons.insights_outlined,
                        onTap: onTrend,
                        semanticLabel: 'Exercise trend'),
                    const SizedBox(width: 6),
                    GbIconButton(
                        icon: Icons.more_horiz,
                        onTap: onMenu,
                        semanticLabel: 'More options'),
                  ],
                ),
                const SizedBox(height: 12),
                _FormCueStrip(catalog: catalog, onTap: onGuide),
                if (supersetTag != null) ...[
                  const SizedBox(height: 8),
                  SupersetCue(supersetTag!),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: gb.borderCard),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                // Show each set's OWN logged rest on that set (the rest you took before logging it), so the
                // value lands on the set you entered it with — not the previous set.
                // Reorder arrows act on lead sets only (a drop cluster moves as a unit); `_leads` gives
                // each lead's position so the up/down affordances disable at the ends.
                for (var i = 0; i < exercise.sets.length; i++)
                  _LoggedSetRow(
                    key: ValueKey('set-${exercise.sets[i].id}'),
                    set: exercise.sets[i],
                    rest: exercise.sets[i].restSeconds,
                    onDelete: () => onDeleteSet(exercise.sets[i]),
                    onEdit: () => onEditSet(exercise.sets[i]),
                    onMoveUp: _leadIndex(exercise.sets[i]) > 0
                        ? () => onMoveSet(exercise.sets[i], true)
                        : null,
                    onMoveDown: () {
                      final li = _leadIndex(exercise.sets[i]);
                      return (li >= 0 && li < _leadCount - 1)
                          ? () => onMoveSet(exercise.sets[i], false)
                          : null;
                    }(),
                  ),
                if (isSkipped)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text('Exercise skipped',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: gb.grey500)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: _EntryRow(
                      setNumber: exercise.sets.length + 1,
                      target: entryTarget,
                      suggestion: suggestion,
                      profile: profile,
                      entry: entry,
                      setType: entryType,
                      busy: busy,
                      canLog: canLog,
                      showMore: showMore,
                      onToggleMore: onToggleMore,
                      onMetric: onMetric,
                      onSetType: onSetType,
                      onLog: onLog,
                    ),
                  ),
                // Upcoming planned sets (beyond the one being logged) — a greyed preview so the whole
                // prescription is visible at a glance: each remaining set's type, target weight × reps
                // and RPE. The entry above covers the current set (planned index = sets.length).
                if (!isSkipped)
                  for (var i = exercise.sets.length + 1;
                      i < snapshotSets.length;
                      i++)
                    _PlannedSetRow(setNumber: i + 1, target: snapshotSets[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A logged (done) set row — design layout: check + type on the left, weight×reps + e1RM right.
/// Tap to edit, up/down arrows to reorder, swipe-left (or long-press) to delete — the row stays clean.
class _LoggedSetRow extends StatelessWidget {
  const _LoggedSetRow({
    super.key,
    required this.set,
    this.rest,
    required this.onDelete,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
  });
  final PerformedSet set;

  /// This set's own logged rest (the rest taken before it was logged), shown on the set itself.
  final int? rest;

  /// Confirms + deletes the set; resolves to true when the set was removed.
  final Future<bool> Function() onDelete;

  /// Tap opens the edit sheet (null = not editable).
  final VoidCallback? onEdit;

  /// Reorder this lead set one slot up/down; null disables that direction (a boundary, or a drop stage).
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  // A wide ~38×24 tap target — easy to hit without the tall stack inflating the row height.
  Widget _arrow(BuildContext c, IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 24,
          child: Icon(icon,
              size: 21, color: onTap == null ? c.gb.grey25 : c.gb.grey500),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final e1rm =
        set.estimatedOneRepMaxKg ?? epleyOneRepMax(set.weightKg, set.reps);
    // Sub-line: e1RM (working strength sets), RPE, and this set's own logged rest.
    final subParts = <String>[
      if (set.setType == PerformedSetType.working && e1rm != null)
        'e1RM ${e1rm.toStringAsFixed(1)}kg',
      if ((set.rpe ?? 0) > 0) 'RPE ${set.rpe}',
      if ((rest ?? 0) > 0) 'rest ${formatRestClock(rest!)}',
    ];
    // Swipe-left reveals a red "delete" panel and runs the confirm flow; long-press
    // is kept as a secondary affordance. confirmDismiss only lets the row animate
    // out when the delete actually went through, so a cancel springs it back.
    return Dismissible(
      key: ValueKey('dismiss-set-${set.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: Container(
        color: gb.danger0,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 18, color: gb.danger),
            const SizedBox(width: 6),
            Text('Delete',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: gb.danger)),
          ],
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        onLongPress: () => onDelete(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              // Done marker: a plain green dot (no check glyph) — the green fill alone reads as "logged".
              Container(
                width: 26,
                height: 26,
                decoration:
                    BoxDecoration(color: gb.success0, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                child: Text(set.setType.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: gb.grey500)),
              ),
              // Value column takes ALL remaining space and right-aligns, so every row's value/sub-line is
              // flush to the same right edge (no Spacer+Flexible splitting the space 50/50).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatLoggedSet(set),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: gb.grey700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    if (subParts.isNotEmpty)
                      Text(subParts.join(' · '),
                          style: TextStyle(
                              fontSize: 11,
                              color: gb.grey500,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                  ],
                ),
              ),
              // Reorder arrows for a lead set (hidden when this row can't move either way — a drop
              // stage, or the only lead). The whole row taps to edit; these win their own taps.
              if (onMoveUp != null || onMoveDown != null) ...[
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _arrow(context, Icons.keyboard_arrow_up, onMoveUp),
                    _arrow(context, Icons.keyboard_arrow_down, onMoveDown),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to edit an already-logged set: a set-type selector + mode-aware steppers (prefilled with
/// what was logged) for the fields the edit endpoint accepts (weight/reps/duration/distance + RPE + rest).
class _EditSetSheet extends StatefulWidget {
  const _EditSetSheet({
    required this.set,
    required this.trackingType,
    required this.onSave,
    required this.onDelete,
  });
  final PerformedSet set;
  final ExerciseTrackingType trackingType;
  final Future<void> Function(EditSetRequest) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<_EditSetSheet> {
  late PerformedSetType _type = widget.set.setType;
  bool _busy = false;
  late final Map<TrackingMetric, num> _v = {
    TrackingMetric.weight: widget.set.weightKg ?? 0,
    TrackingMetric.reps: widget.set.reps ?? 0,
    TrackingMetric.duration: widget.set.durationSeconds ?? 0,
    TrackingMetric.distance: widget.set.distanceM ?? 0,
    TrackingMetric.rounds: widget.set.rounds ?? 0,
    TrackingMetric.calories: widget.set.calories ?? 0,
    TrackingMetric.heartRate: widget.set.avgHeartRate ?? 0,
    TrackingMetric.incline: widget.set.inclinePercent ?? 0,
    TrackingMetric.speed: widget.set.speedKph ?? 0,
    TrackingMetric.level: widget.set.level ?? 0,
    TrackingMetric.rest: widget.set.restSeconds ?? 0,
    TrackingMetric.rpe: widget.set.rpe ?? 0,
  };

  static ({String label, String? unit, num step}) _spec(TrackingMetric m) =>
      switch (m) {
        TrackingMetric.weight => (label: 'WEIGHT', unit: 'kg', step: 2.5),
        TrackingMetric.reps => (label: 'REPS', unit: null, step: 1),
        TrackingMetric.duration => (label: 'DURATION', unit: 'sec', step: 5),
        TrackingMetric.distance => (label: 'DISTANCE', unit: 'm', step: 50),
        TrackingMetric.rounds => (label: 'ROUNDS', unit: null, step: 1),
        TrackingMetric.calories => (label: 'CALORIES', unit: 'kcal', step: 5),
        TrackingMetric.heartRate => (label: 'AVG HR', unit: 'bpm', step: 1),
        TrackingMetric.incline => (label: 'INCLINE', unit: '%', step: 0.5),
        TrackingMetric.speed => (label: 'SPEED', unit: 'km/h', step: 0.5),
        TrackingMetric.level => (label: 'LEVEL', unit: null, step: 1),
        TrackingMetric.rest => (label: 'REST', unit: 'sec', step: 5),
        TrackingMetric.rpe => (label: 'RPE', unit: null, step: 1),
      };

  num _val(TrackingMetric m) => _v[m] ?? 0;

  Future<void> _save() async {
    setState(() => _busy = true);
    // Mirror the logger: only the metrics this exercise's mode uses (primary + secondary), plus RPE.
    final profile = trackingProfileFor(widget.trackingType);
    final keep = {...profile.fields, ...profile.extras};
    int? gi(TrackingMetric m) =>
        keep.contains(m) && _val(m) > 0 ? _val(m).toInt() : null;
    double? gd(TrackingMetric m) =>
        keep.contains(m) && _val(m) > 0 ? _val(m).toDouble() : null;
    final req = EditSetRequest(
      setType: _type,
      reps: gi(TrackingMetric.reps),
      weightKg: keep.contains(TrackingMetric.weight) &&
              _val(TrackingMetric.weight) > 0
          ? _val(TrackingMetric.weight).toDouble()
          : null,
      durationSeconds: gi(TrackingMetric.duration),
      distanceM: gi(TrackingMetric.distance),
      rounds: gi(TrackingMetric.rounds),
      inclinePercent: gd(TrackingMetric.incline),
      speedKph: gd(TrackingMetric.speed),
      level: gi(TrackingMetric.level),
      calories: gi(TrackingMetric.calories),
      avgHeartRate: gi(TrackingMetric.heartRate),
      rpe: _val(TrackingMetric.rpe) > 0
          ? _val(TrackingMetric.rpe).toInt()
          : null,
      restSeconds:
          keep.contains(TrackingMetric.rest) && _val(TrackingMetric.rest) > 0
              ? _val(TrackingMetric.rest).toInt()
              : null,
    );
    try {
      await widget.onSave(req);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stepper(TrackingMetric m) {
    final spec = _spec(m);
    return GbStepper(
      label: spec.label,
      semanticLabel: spec.label,
      value: _val(m),
      unit: spec.unit,
      step: spec.step,
      max: m == TrackingMetric.rpe ? 10 : 100000,
      onChanged: (v) => setState(() => _v[m] = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final profile = trackingProfileFor(widget.trackingType);
    // Mode-aware + deduped: the mode's primary + secondary metrics, then RPE — the logger's exact fields.
    final metrics = <TrackingMetric>[];
    for (final m in [
      ...profile.fields,
      ...profile.extras,
      TrackingMetric.rpe
    ]) {
      if (!metrics.contains(m)) metrics.add(m);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GbSheetHeader(
              title: 'Edit set', subtitle: 'Update what you logged.'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in const [
                PerformedSetType.warmup,
                PerformedSetType.working,
                PerformedSetType.drop,
                PerformedSetType.amrap,
                PerformedSetType.failure,
              ])
                GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _type == t ? gb.primary0 : gb.grey0,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: _type == t ? gb.primary500 : gb.borderCard),
                    ),
                    child: Text(t.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _type == t ? gb.primary700 : gb.grey600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < metrics.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: _stepper(metrics[i])),
                  const SizedBox(width: AppSpacing.xs),
                  if (i + 1 < metrics.length)
                    Expanded(child: _stepper(metrics[i + 1]))
                  else
                    const Spacer(),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          GbButton(
            label: 'Save changes',
            icon: Icons.check,
            full: true,
            onPressed: _busy ? null : _save,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _busy ? null : () => widget.onDelete(),
            icon: Icon(Icons.delete_outline, size: 18, color: gb.danger),
            label: Text('Delete set', style: TextStyle(color: gb.danger)),
          ),
        ],
      ),
    );
  }
}

/// Compact "how long ago" for the last-performed chip: 'today', 'yesterday', '5d ago', '3w ago', '4mo ago',
/// '2y ago'. Empty when there's no date. Keeps the recency tight enough to sit inside a meta pill.
String lastPerformedAgo(DateTime? d) {
  if (d == null) return '';
  final today = DateTime.now();
  final day = d.toLocal();
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(day.year, day.month, day.day))
      .inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '${days}d ago';
  if (days < 30) return '${days ~/ 7}w ago';
  if (days < 365) return '${days ~/ 30}mo ago';
  return '${days ~/ 365}y ago';
}

/// Compact, mode-aware target string for a planned set: "27.5kg × 6 · RPE 10" (or reps/duration/distance/
/// rounds as the mode dictates). Weight keeps its half-kg (no rounding); zero-valued metrics are dropped.
String formatPlannedTarget(SessionSnapshotSet t) {
  final parts = <String>[];
  final w = t.targetWeightKg ?? 0;
  final r = t.targetReps ?? 0;
  if (w > 0 && r > 0) {
    parts.add('${w % 1 == 0 ? w.toInt() : w}kg × $r');
  } else if (r > 0) {
    parts.add('$r reps');
  } else if (w > 0) {
    parts.add('${w % 1 == 0 ? w.toInt() : w}kg');
  }
  if ((t.targetDurationSeconds ?? 0) > 0) {
    parts.add(formatDuration(t.targetDurationSeconds!));
  }
  if ((t.targetDistanceM ?? 0) > 0) parts.add('${t.targetDistanceM}m');
  if ((t.targetRounds ?? 0) > 0) parts.add('${t.targetRounds} rounds');
  if ((t.targetRpe ?? 0) > 0) parts.add('RPE ${t.targetRpe}');
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// A greyed, read-only preview of an upcoming planned set: number badge + type + the plan's target. Shows
/// what's prescribed so the whole workout is visible at a glance; it becomes loggable once it's the
/// current set (then the highlighted entry card takes over).
class _PlannedSetRow extends StatelessWidget {
  const _PlannedSetRow({required this.setNumber, required this.target});
  final int setNumber;
  final SessionSnapshotSet target;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final type = PerformedSetType.parse(target.setType.wire);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: gb.grey25, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$setNumber',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gb.grey500)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(type.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: gb.grey400)),
          ),
          Expanded(
            child: Text(formatPlannedTarget(target),
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: gb.grey500,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ],
      ),
    );
  }
}

/// The highlighted current-set entry card (design): set chip + set-type selector + target, big
/// weight/reps steppers, Epley e1RM, gradient Log-set button.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.setNumber,
    required this.target,
    this.suggestion,
    required this.profile,
    required this.entry,
    required this.setType,
    required this.busy,
    required this.canLog,
    required this.showMore,
    required this.onToggleMore,
    required this.onMetric,
    required this.onSetType,
    required this.onLog,
  });
  final int setNumber;
  final SessionSnapshotSet? target;

  /// Pre-log weight × reps suggestion (plan / last-time / RPE / readiness); null when there's nothing
  /// to suggest (cardio, or a brand-new lift with no plan or history).
  final SetSuggestion? suggestion;
  final TrackingProfile profile;
  final Map<TrackingMetric, num> entry;
  final PerformedSetType setType;
  final bool busy;
  final bool canLog;
  final bool showMore;
  final VoidCallback onToggleMore;
  final void Function(TrackingMetric, num) onMetric;
  final ValueChanged<PerformedSetType> onSetType;
  final VoidCallback onLog;

  num _val(TrackingMetric m) => entry[m] ?? 0;

  /// Essential steppers + RPE — the headline effort field, shown for every mode by default (it's not in
  /// any tracking profile because it's universal, not mode-specific). Secondary metrics (calories / HR /
  /// rest) still appear only via "+ More".
  List<TrackingMetric> get _stepperFields =>
      [...profile.fields, TrackingMetric.rpe, if (showMore) ...profile.extras];

  static ({String label, String? unit, num step}) _metricSpec(
          TrackingMetric m) =>
      switch (m) {
        TrackingMetric.weight => (label: 'WEIGHT', unit: 'kg', step: 2.5),
        TrackingMetric.reps => (label: 'REPS', unit: null, step: 1),
        TrackingMetric.duration => (label: 'DURATION', unit: 'sec', step: 5),
        TrackingMetric.distance => (label: 'DISTANCE', unit: 'm', step: 50),
        TrackingMetric.rounds => (label: 'ROUNDS', unit: null, step: 1),
        TrackingMetric.calories => (label: 'CALORIES', unit: 'kcal', step: 5),
        TrackingMetric.heartRate => (label: 'AVG HR', unit: 'bpm', step: 1),
        TrackingMetric.incline => (label: 'INCLINE', unit: '%', step: 0.5),
        TrackingMetric.speed => (label: 'SPEED', unit: 'km/h', step: 0.5),
        TrackingMetric.level => (label: 'LEVEL', unit: null, step: 1),
        TrackingMetric.rest => (label: 'REST', unit: 'sec', step: 5),
        TrackingMetric.rpe => (label: 'RPE', unit: null, step: 1),
      };

  /// Mode-aware prescribed-target hint shown on the entry header.
  String? _targetHint() {
    final t = target;
    if (t == null) return null;
    final parts = <String>[];
    if (t.targetWeightKg != null && t.targetReps != null) {
      parts.add('${t.targetWeightKg!.toStringAsFixed(0)}kg × ${t.targetReps}');
    } else if (t.targetReps != null) {
      parts.add('${t.targetReps} reps');
    }
    if (t.targetDurationSeconds != null)
      parts.add('${t.targetDurationSeconds}s');
    if (t.targetDistanceM != null) parts.add('${t.targetDistanceM}m');
    if (t.targetRounds != null) parts.add('${t.targetRounds} rounds');
    return parts.isEmpty ? null : 'Target ${parts.join(' · ')}';
  }

  /// Pre-log suggestion chip — "Suggested 52.5kg × 6" plus its reason, with a one-tap "Use" that
  /// prefills the weight/reps steppers. It never auto-logs; the user still confirms with Log set below.
  Widget _suggestionBar(BuildContext context, SetSuggestion s) {
    final gb = context.gb;
    final w = s.weightKg % 1 == 0
        ? s.weightKg.toInt().toString()
        : s.weightKg.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gb.primary500.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: gb.primary600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Suggested ${w}kg × ${s.reps}',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: gb.grey900,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Text(s.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: gb.grey500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // "Use" prefills the steppers only — the user still taps Log set to confirm.
          Material(
            color: gb.primary500,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                onMetric(TrackingMetric.weight, s.weightKg);
                onMetric(TrackingMetric.reps, s.reps);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text('Use',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the mode's metric steppers in a fixed two-column grid. Each stepper is left-aligned in its
  /// column so the ± buttons line up vertically across every row (the lone last stepper keeps the left column).
  Widget _buildSteppers(GbColors gb) {
    final fields = _stepperFields;
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      final pair = fields.skip(i).take(2).toList();
      rows.add(IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: _stepperFor(pair[0]))),
            const SizedBox(width: 6),
            Container(width: 1, color: gb.primary500.withValues(alpha: 0.18)),
            const SizedBox(width: 6),
            Expanded(
                child: pair.length > 1
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: _stepperFor(pair[1]))
                    : const SizedBox.shrink()),
          ],
        ),
      ));
      if (i + 2 < fields.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _stepperFor(TrackingMetric m) {
    final spec = _metricSpec(m);
    return GbStepper(
      label: spec.label,
      semanticLabel: spec.label,
      value: _val(m),
      unit: spec.unit,
      step: spec.step,
      max: m == TrackingMetric.rpe ? 10 : 100000,
      onChanged: (v) => onMetric(m, v),
    );
  }

  static String _setTypeDesc(PerformedSetType t) => switch (t) {
        PerformedSetType.warmup =>
          'Lighter prep — not counted as working volume.',
        PerformedSetType.working => 'Counts toward your plan and e1RM.',
        PerformedSetType.drop => 'Reduced weight right after a working set.',
        PerformedSetType.amrap => 'As many reps as possible.',
        PerformedSetType.failure => 'Taken to muscular failure.',
      };

  /// Set type opens a bottom-sheet picker (design rule: pickers are sheets, never inline cycles) so
  /// the dropdown-styled chip behaves like a dropdown.
  Future<void> _pickSetType(BuildContext context) async {
    final picked = await showGbSheet<PerformedSetType>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GbSheetHeader(
                title: 'Set type',
                subtitle: 'How this set counts toward your plan.'),
            const SizedBox(height: AppSpacing.sm),
            for (final t in _setTypeCycle)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: GbTappableRow(
                  title: t.label,
                  subtitle: _setTypeDesc(t),
                  trailing: t == setType
                      ? Icon(Icons.check, color: ctx.gb.primary600)
                      : null,
                  onTap: () => Navigator.pop(ctx, t),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onSetType(picked);
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final e1rm = epleyOneRepMax(_val(TrackingMetric.weight).toDouble(),
        _val(TrackingMetric.reps).toInt());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppPalette.primary0, AppPalette.primaryTint],
        ),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: gb.primary500.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: gb.primary500.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: AppPalette.primary500, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$setNumber',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              // Set-type selector — cycles warmup → working → drop → amrap.
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                  side: BorderSide(color: gb.primary500.withValues(alpha: 0.4)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => _pickSetType(context),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(setType.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: gb.primary700)),
                        Icon(Icons.expand_more, size: 15, color: gb.primary500),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_targetHint() != null)
                Text(_targetHint()!,
                    style: TextStyle(
                        fontSize: 12,
                        color: gb.grey500,
                        fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 14),
          if (suggestion != null) _suggestionBar(context, suggestion!),
          _buildSteppers(gb),
          if (profile.extras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onToggleMore,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(showMore ? Icons.expand_less : Icons.tune,
                              size: 15, color: gb.primary600),
                          const SizedBox(width: 6),
                          Text(
                              showMore
                                  ? 'Hide extra fields'
                                  : 'More fields (rest, calories…)',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: gb.primary600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (setType == PerformedSetType.working && e1rm != null) ...[
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Est. 1RM '),
                TextSpan(
                    text: '${e1rm.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const TextSpan(text: ' · Epley'),
              ]),
              style: TextStyle(fontSize: 12, color: gb.grey500),
            ),
          ],
          const SizedBox(height: 12),
          // Design CTA: full-width hero-gradient button (GbButton) with a check + "Log set". Disabled
          // until the mode's required metric is present; the labelled fields above make that obvious.
          GbButton(
            label: 'Log set',
            icon: Icons.check,
            size: GbButtonSize.lg,
            full: true,
            busy: busy,
            onPressed: (busy || !canLog) ? null : onLog,
          ),
        ],
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar(
      {required this.rest, required this.onAdd, required this.onSkip});
  final RestTimerState rest;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: GbColors.heroDeepGradient),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
      child: Row(
        children: [
          GbRing(
            value:
                rest.total > 0 ? (rest.total - rest.remaining) / rest.total : 0,
            size: 42,
            stroke: 4.5,
            gradient: const [AppPalette.restRingLight, AppPalette.liveDot],
            trackColor: Colors.white24,
            child: Text('${rest.remaining}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest · ${formatRestClock(rest.remaining)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                Text('Next: set ready when you are',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11)),
              ],
            ),
          ),
          _RestBtn(label: '+15s', onTap: onAdd),
          const SizedBox(width: AppSpacing.xs),
          _RestBtn(label: 'Skip', onTap: onSkip, filled: true),
        ],
      ),
    );
  }
}

/// Translucent "glass" pill action on the navy rest bar — the kit's [GbButton] is light-on-light so
/// it can't sit on the dark gradient; this is the design's on-dark treatment.
class _RestBtn extends StatelessWidget {
  const _RestBtn(
      {required this.label, required this.onTap, this.filled = false});
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: filled ? 0.16 : 0.10),
      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gap, vertical: AppSpacing.xs),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canPrev,
    required this.isLast,
    required this.busy,
    required this.onPrev,
    required this.onNext,
    required this.onFinish,
    this.editing = false,
  });
  final bool canPrev;
  final bool isLast;
  final bool busy;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  /// Editing a finished workout → the primary action is "Done" (leave), not "Finish workout".
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs + 2, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: gb.card,
        border: Border(top: BorderSide(color: gb.borderCard)),
      ),
      child: Row(
        children: [
          // Prev = a clean square icon button (was an empty outlined box). Shown only when there's a
          // previous exercise; back/forward is also available via the pager chips above.
          if (canPrev) ...[
            GbIconButton(
              icon: Icons.chevron_left,
              semanticLabel: 'Previous exercise',
              size: AppSizes.buttonHeight,
              fill: gb.card,
              onTap: onPrev,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Expanded(
            child: isLast
                ? GbButton(
                    label: editing ? 'Done' : 'Finish workout',
                    icon: editing ? Icons.check : Icons.flag,
                    full: true,
                    busy: busy,
                    onPressed: onFinish,
                  )
                : GbButton(
                    label: 'Next exercise',
                    iconRight: Icons.chevron_right,
                    variant: GbButtonVariant.outlined,
                    severity: GbButtonSeverity.secondary,
                    full: true,
                    onPressed: onNext,
                  ),
          ),
        ],
      ),
    );
  }
}

// Catalog filter taxonomies. Category = the API's 13 fine library codes (a superset of the 6 muscle groups);
// equipment = the Equipment enum. Order is the chip display order; values absent from the catalog are skipped.
const List<String> _kCategoryOrder = [
  'chest', 'back', 'shoulders', 'biceps', 'triceps', 'quadriceps', 'hamstrings',
  'glutes', 'calves', 'abs', 'cardio', 'full-body', 'mobility',
];
const Map<String, String> _kCategoryLabels = {
  'chest': 'Chest', 'back': 'Back', 'shoulders': 'Shoulders', 'biceps': 'Biceps',
  'triceps': 'Triceps', 'quadriceps': 'Quads', 'hamstrings': 'Hamstrings',
  'glutes': 'Glutes', 'calves': 'Calves', 'abs': 'Abs', 'cardio': 'Cardio',
  'full-body': 'Full Body', 'mobility': 'Mobility',
};
const List<String> _kEquipmentOrder = [
  'Barbell', 'Dumbbell', 'Cable', 'Machine', 'Bodyweight', 'ResistanceBand',
];

String _categoryLabel(String c) =>
    c == 'All' ? 'All' : (_kCategoryLabels[c] ?? _titleCase(c));
String _equipmentLabel(String q) => q == 'All'
    ? 'All'
    : (q == 'ResistanceBand' ? 'Band' : q);
String _titleCase(String s) => s.isEmpty
    ? s
    : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

/// Exercise-catalog picker (substitute / add) — search + category & equipment filters over the global catalog.
class _CatalogSheet extends ConsumerStatefulWidget {
  const _CatalogSheet({required this.title, required this.onPick});
  final String title;
  final ValueChanged<ExerciseSummary> onPick;

  @override
  ConsumerState<_CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends ConsumerState<_CatalogSheet> {
  late final Future<List<ExerciseSummary>> _future;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = 'All';
  String _equipment = 'All';

  @override
  void initState() {
    super.initState();
    _future = ref.read(exerciseRepositoryProvider).search();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filter bar: a pinned Equipment dropdown (secondary axis) on the left, then a horizontally
  /// scrolling row of category chips (primary axis). One compact row instead of two chip rows.
  Widget _filterBar(List<String> categories, List<String> equipments) {
    final gb = context.gb;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          _equipmentDropdown(equipments),
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: 22, color: gb.borderCard),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GbChip(
                        label: _categoryLabel(c),
                        selected: _category == c,
                        onTap: () => setState(() => _category = c)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact equipment filter — a pill that opens a dropdown menu of the equipment present. Reads as a
  /// neutral "Equipment ▾" until a value is picked, then turns into a filled "Cable ▾"-style active chip.
  Widget _equipmentDropdown(List<String> equipments) {
    final gb = context.gb;
    final active = _equipment != 'All';
    return PopupMenuButton<String>(
      initialValue: _equipment,
      position: PopupMenuPosition.under,
      onSelected: (q) => setState(() => _equipment = q),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      itemBuilder: (_) => [
        for (final q in equipments)
          PopupMenuItem<String>(
            value: q,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: q == _equipment
                      ? Icon(Icons.check, size: 16, color: gb.primary600)
                      : null,
                ),
                Text(_equipmentLabel(q),
                    style: TextStyle(
                        fontWeight: q == _equipment
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? gb.primary600 : gb.card,
          borderRadius: BorderRadius.circular(99),
          border:
              Border.all(color: active ? gb.primary600 : gb.borderCard),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune,
                size: 14, color: active ? Colors.white : gb.grey400),
            const SizedBox(width: 5),
            Text(active ? _equipmentLabel(_equipment) : 'Equipment',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : gb.ink)),
            Icon(Icons.arrow_drop_down,
                size: 18, color: active ? Colors.white : gb.grey400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Padding(
        // Lift the sheet's content above the on-screen keyboard so the search results stay visible
        // while typing — without this the keyboard covers the exercise list.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FutureBuilder<List<ExerciseSummary>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError)
              return ErrorRetry(message: snap.error.toString());
            final all = snap.data ?? const [];
            // Two filter axes: library CATEGORY (fine — Glutes/Biceps/Cardio/…, beyond the 6 coarse muscle
            // groups) and EQUIPMENT (Barbell/Dumbbell/Cable/Machine/…). Each chip row lists only the values
            // actually present, in a sensible order. Falls back gracefully if the API predates `category`.
            final cats = <String>{
              for (final e in all)
                if (e.category.isNotEmpty) e.category
            };
            final categories = <String>[
              'All',
              for (final c in _kCategoryOrder)
                if (cats.contains(c)) c,
              for (final c in cats)
                if (!_kCategoryOrder.contains(c)) c,
            ];
            final eqs = <String>{
              for (final e in all)
                if (e.equipment.isNotEmpty) e.equipment
            };
            final equipments = <String>[
              'All',
              for (final q in _kEquipmentOrder)
                if (eqs.contains(q)) q,
              for (final q in eqs)
                if (!_kEquipmentOrder.contains(q)) q,
            ];
            final filtered = all.where((e) {
              final byCat = _category == 'All' || e.category == _category;
              final byEq = _equipment == 'All' || e.equipment == _equipment;
              final byQuery = _query.isEmpty ||
                  e.name.toLowerCase().contains(_query.toLowerCase());
              return byCat && byEq && byQuery;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GbSheetHeader(
                      title: widget.title,
                      subtitle: widget.title == 'Substitute'
                          ? 'Replace ${widget.title.toLowerCase()} for this session. Tap to preview the guide.'
                          : 'Tap a movement to preview its guide — then add.',
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: GbSearchField(
                    controller: _search,
                    hint: 'Search exercises…',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                _filterBar(categories, equipments),
                Expanded(
                  child: ListView.separated(
                    controller: scroll,
                    // Dragging the list dismisses the keyboard, so the user can swipe down to see more
                    // results without first reaching for a "done" key.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                        AppSpacing.xs, AppSpacing.md, AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (ctx, i) {
                      final e = filtered[i];
                      final meta = [e.muscleGroup, e.equipment]
                          .where((s) => s.isNotEmpty)
                          .join(' · ');
                      return _CatalogRow(
                        exercise: e,
                        meta: meta,
                        onGuide: () => presentGuideSheet(
                          context,
                          _GuideSheet(
                            exerciseId: e.id,
                            exerciseName: e.name,
                            catalog: e,
                            repository: ref.read(exerciseRepositoryProvider),
                            eyebrow: widget.title == 'Substitute'
                                ? 'PREVIEW · SUBSTITUTE'
                                : 'PREVIEW · BEFORE ADDING',
                            footer: Row(
                              children: [
                                GbButton(
                                  label: 'Back',
                                  variant: GbButtonVariant.outlined,
                                  severity: GbButtonSeverity.secondary,
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GbButton(
                                    label: widget.title == 'Substitute'
                                        ? 'Use this exercise'
                                        : 'Add to session',
                                    icon: widget.title == 'Substitute'
                                        ? Icons.swap_horiz
                                        : Icons.add,
                                    full: true,
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onPick(e);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        onAdd: () => widget.onPick(e),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Catalog row with a "Guide >" preview pill and a + add button — matches the design
/// where tapping a row previews the guide before committing the add/substitute.
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.exercise,
    required this.meta,
    required this.onGuide,
    required this.onAdd,
  });
  final ExerciseSummary exercise;
  final String meta;
  final VoidCallback onGuide;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Tapping the row body opens the guide preview (then Back / Add from there); the trailing
    // circle still adds straight to the session in one tap.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: gb.borderCard, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onGuide,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: gb.grey0,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.fitness_center, size: 19, color: gb.grey500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: gb.grey900)),
                    if (meta.isNotEmpty)
                      Text(meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: gb.grey500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Add circle button — its own tap target so it adds without opening the preview.
              Material(
                color: gb.primary500,
                shape: const CircleBorder(),
                shadowColor: gb.primary500.withValues(alpha: 0.55),
                elevation: 3,
                child: InkWell(
                  onTap: onAdd,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation sheet (design treatment) — rounded icon tile, header + message, danger CTA +
/// secondary outlined cancel. Returns `true` on confirm.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GbIconTile(
            size: 48,
            radius: AppRadius.sm + 2,
            background: gb.danger0,
            child: Icon(icon, size: AppSizes.iconXxl, color: gb.danger),
          ),
          const SizedBox(height: AppSpacing.sm),
          GbSheetHeader(title: title, subtitle: message),
          const SizedBox(height: AppSpacing.md + 2),
          GbButton(
            label: confirmLabel,
            severity: GbButtonSeverity.danger,
            full: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          GbButton(
            label: cancelLabel,
            severity: GbButtonSeverity.secondary,
            variant: GbButtonVariant.outlined,
            full: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

// ── Form Coach widgets ────────────────────────────────────────────────────────

/// Present a coach/guide sheet. Uses showModalBottomSheet with the theme drag handle OFF (the sheet
/// draws its own compact handle) so the header stays tight and there's never a double handle —
/// regardless of which entry point (active card, or the add/substitute preview) opens it.
Future<void> presentGuideSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: context.gb.card,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => sheet,
  );
}

/// Public entrypoint to open the Form Coach guide for an exercise by id — reused by the plan views and
/// the lift-detail screen. [catalog] is an optional fallback (muscles/equipment) shown while the full
/// `ExerciseDetail` loads from [repository].
Future<void> openExerciseGuide(
  BuildContext context, {
  required String exerciseId,
  required String exerciseName,
  required ExerciseRepository repository,
  ExerciseSummary? catalog,
}) =>
    presentGuideSheet(
      context,
      _GuideSheet(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        catalog: catalog,
        repository: repository,
      ),
    );

/// A compact "open the exercise guide" icon button — self-contained (reads the catalog + repository),
/// so it drops into any row that has an exercise id (plan views, etc.).
class GuideButton extends ConsumerWidget {
  const GuideButton({required this.exerciseId, required this.name, super.key});
  final String exerciseId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded, size: 20),
      color: context.gb.primary600,
      tooltip: 'Exercise guide',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: () => openExerciseGuide(
        context,
        exerciseId: exerciseId,
        exerciseName: name,
        repository: ref.read(exerciseRepositoryProvider),
        catalog: ref.read(exerciseCatalogProvider).valueOrNull?[exerciseId],
      ),
    );
  }
}

/// Zero-tap coaching line on the exercise card — always visible, one tap opens the guide sheet.
/// Mirrors the design's form-cue strip: tinted bar, target icon, the single highest-value cue,
/// and a "Guide ›" pill.
class _FormCueStrip extends StatelessWidget {
  const _FormCueStrip({required this.catalog, required this.onTap});
  final ExerciseSummary? catalog;
  final VoidCallback onTap;

  String _cueText() {
    // Prefer the authored coaching cue; otherwise a muscle-aware generic line.
    final authored = authoredCueFor(catalog?.name);
    if (authored != null) return authored;
    final muscle = catalog?.muscleGroup.isNotEmpty == true
        ? catalog!.muscleGroup.toLowerCase()
        : 'target muscles';
    return 'Focus on your $muscle — controlled reps, full range';
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Rounded, inset tinted bar (full width within the card's 16px padding) — design `--gb-r-sm`.
    return Material(
      color: _kPrimaryTint,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(11, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: gb.primary25),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: gb.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gb.primary25),
                ),
                child: Icon(Icons.gps_fixed, size: 15, color: gb.primary600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _cueText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: gb.primary800,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 26,
                padding: const EdgeInsets.fromLTRB(9, 0, 6, 0),
                decoration: BoxDecoration(
                  color: gb.card,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: gb.primary25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Guide',
                        style: TextStyle(
                            color: gb.primary700,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 13, color: gb.primary500),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test seam — the inset form-cue strip as it sits inside the exercise card (with the card's white
/// surface + 16px padding around it), so its margin/rounding can be verified with a golden.
@visibleForTesting
Widget buildFormCueStripForTest({required ExerciseSummary catalog}) => Builder(
      builder: (context) => ColoredBox(
        color: context.gb.card,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _FormCueStrip(catalog: catalog, onTap: () {}),
        ),
      ),
    );

/// Renders the Form Coach guide sheet against a pre-resolved [detail] future — a test seam so the
/// sheet's styling can be verified with golden images without standing up the API.
@visibleForTesting
Widget buildGuideSheetForTest({
  required Future<ExerciseDetail> detail,
  required String exerciseName,
  ExerciseSummary? catalog,
  String eyebrow = 'How to do this',
  Widget? footer,
}) =>
    _GuideSheet(
      exerciseName: exerciseName,
      catalog: catalog,
      detailFuture: detail,
      eyebrow: eyebrow,
      footer: footer,
    );

/// One-tap coach sheet — loads full exercise detail, resolves the [CoachGuide], and presents the
/// design's progressively-disclosed guide: identity + media, muscle targets, and a tabbed body
/// (Steps / Setup / Cues / Mistakes).
class _GuideSheet extends StatefulWidget {
  const _GuideSheet({
    this.exerciseId,
    required this.exerciseName,
    required this.catalog,
    this.repository,
    this.detailFuture,
    this.eyebrow = 'How to do this',
    this.footer,
  }) : assert(
            detailFuture != null || (repository != null && exerciseId != null),
            'Provide either a detailFuture or a repository + exerciseId');
  final String? exerciseId;
  final String exerciseName;
  final ExerciseSummary? catalog;
  final ExerciseRepository? repository;

  /// Pre-resolved detail (tests/previews); when null the [repository] is queried by [exerciseId].
  final Future<ExerciseDetail>? detailFuture;
  final String eyebrow;
  final Widget? footer;

  @override
  State<_GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<_GuideSheet> {
  late final Future<ExerciseDetail> _future;
  _GuideTab _tab = _GuideTab.steps;

  @override
  void initState() {
    super.initState();
    _future =
        widget.detailFuture ?? widget.repository!.getById(widget.exerciseId!);
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      builder: (ctx, scroll) => FutureBuilder<ExerciseDetail>(
        future: _future,
        builder: (ctx, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          final guide =
              snap.data != null ? resolveCoachGuide(snap.data!) : null;
          // Fall back to the catalog summary for the muscle targets while detail loads / on error.
          final fallbackPrimary = widget.catalog?.muscleGroup.isNotEmpty == true
              ? [widget.catalog!.muscleGroup]
              : const <String>[];
          final equipment = guide?.equipment?.isNotEmpty == true
              ? guide!.equipment!
              : (widget.catalog?.equipment ?? '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact drag handle (theme handle is disabled for this sheet to keep the top tight).
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: gb.grey25,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              // ── Eyebrow + close ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.eyebrow.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: gb.primary600)),
                    ),
                    _SheetCloseButton(onTap: () => Navigator.of(ctx).pop()),
                  ],
                ),
              ),
              // ── Title + difficulty ── (more breathing room below the eyebrow/close row)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(widget.exerciseName,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.18,
                              color: gb.ink)),
                    ),
                    if (guide?.difficulty?.isNotEmpty == true) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _DifficultyBadge(label: guide!.difficulty!),
                      ),
                    ],
                  ],
                ),
              ),
              // ── Media slot — ALWAYS shown (photo when available, else a placeholder), with the
              // equipment + "Demo loop" chips overlaid, exactly as the design specifies.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _MediaSlot(
                  imageUrl: guide?.imageUrl,
                  equipment: equipment,
                  exerciseName: widget.exerciseName,
                  primary: guide?.primary.isNotEmpty == true
                      ? guide!.primary
                      : fallbackPrimary,
                  secondary: guide?.secondary ?? const [],
                  detailedPrimary: guide?.detailedPrimary ?? const [],
                  detailedSecondary: guide?.detailedSecondary ?? const [],
                ),
              ),
              // ── Targets ──
              if (!loading)
                _TargetsRow(
                  primary: guide?.primary.isNotEmpty == true
                      ? guide!.primary
                      : fallbackPrimary,
                  secondary: guide?.secondary ?? const [],
                  detailedPrimary: guide?.detailedPrimary ?? const [],
                  detailedSecondary: guide?.detailedSecondary ?? const [],
                ),
              const SizedBox(height: 2),
              // ── Body ──
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : snap.hasError || guide == null
                        ? _GuideErrorBody(scroll: scroll)
                        : guide.hasTabs
                            ? _TabbedGuide(
                                guide: guide,
                                tab: _tab,
                                onTab: (t) => setState(() => _tab = t),
                                scroll: scroll,
                              )
                            : _ComingSoonBody(
                                exerciseName: guide.name, scroll: scroll),
              ),
              if (widget.footer != null)
                Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 12 + MediaQuery.of(ctx).padding.bottom),
                  decoration: BoxDecoration(
                    color: gb.card,
                    border: Border(top: BorderSide(color: gb.borderCard)),
                  ),
                  child: widget.footer,
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _GuideTab { steps, setup, cues, mistakes }

extension on _GuideTab {
  String get label => switch (this) {
        _GuideTab.steps => 'Steps',
        _GuideTab.setup => 'Setup',
        _GuideTab.cues => 'Cues',
        _GuideTab.mistakes => 'Mistakes',
      };
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Material(
      color: gb.grey0,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: gb.borderCard),
          ),
          child: Icon(Icons.close, size: 18, color: gb.grey600),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _kPrimaryTint,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: gb.primary25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 11, color: gb.primary600),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: gb.primary700)),
        ],
      ),
    );
  }
}

/// 16:9 media slot — a swipeable carousel of the exercise photo and the muscle-activation figure
/// (photo first, map second) with a page-dots indicator. Falls back to whichever single page exists, or
/// a grey dumbbell placeholder. Equipment + "Demo loop" chips overlay the bottom corners.
class _MediaSlot extends StatefulWidget {
  const _MediaSlot({
    required this.imageUrl,
    required this.equipment,
    required this.exerciseName,
    required this.primary,
    required this.secondary,
    this.detailedPrimary = const [],
    this.detailedSecondary = const [],
  });
  final String? imageUrl;
  final String equipment;
  final String exerciseName;

  /// Worked muscle names — the slot renders a muscle-activation figure from these as a carousel page
  /// (the free-layer media baseline) alongside the photo.
  final List<String> primary;
  final List<String> secondary;

  /// Specific (fine) muscle slugs from the catalog — drive the activation figure accurately.
  final List<String> detailedPrimary;
  final List<String> detailedSecondary;

  @override
  State<_MediaSlot> createState() => _MediaSlotState();
}

class _MediaSlotState extends State<_MediaSlot> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int target, int count) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(target.clamp(0, count - 1),
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // The catalog seeds ImageUrl as an EMPTY string (not null), so guard on blank too — otherwise a loaded
    // exercise (imageUrl == "") falls into Image.network("") and the muscle map flashes then gets replaced.
    final hasImage =
        widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty;
    final hasMap = muscleMapHasContent(
      widget.primary,
      widget.secondary,
      detailedPrimary: widget.detailedPrimary,
      detailedSecondary: widget.detailedSecondary,
    );

    // Carousel pages, in order: photo first, muscle-activation map second.
    final pages = <Widget>[
      if (hasImage)
        Image.network(widget.imageUrl!,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(gb)),
      if (hasMap)
        ColoredBox(
          color: gb.grey0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: MuscleMapFigure(
              exerciseName: widget.exerciseName,
              primary: widget.primary,
              secondary: widget.secondary,
              detailedPrimary: widget.detailedPrimary,
              detailedSecondary: widget.detailedSecondary,
            ),
          ),
        ),
    ];
    if (pages.isEmpty) pages.add(_placeholder(gb));

    final activePage = _page.clamp(0, pages.length - 1);
    final photoActive = hasImage && activePage == 0;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pages.length == 1)
              pages.first
            else
              // Drive paging ourselves so the swipe is reliable: the PageView's own horizontal drag loses
              // to the nested draggable bottom sheet, so we disable it (NeverScrollable) and page on the
              // GestureDetector's horizontal-drag (swipe) and tap (toggle) instead.
              GestureDetector(
                onTap: () =>
                    _go((activePage + 1) % pages.length, pages.length),
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -80) {
                    _go(activePage + 1, pages.length); // swipe left → next
                  } else if (v > 80) {
                    _go(activePage - 1, pages.length); // swipe right → prev
                  }
                },
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: pages,
                ),
              ),
            // Border overlay (over the image too).
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: gb.borderCard),
              ),
            ),
            // Equipment pinned to the bottom-left corner.
            if (widget.equipment.isNotEmpty)
              Positioned(
                left: 10,
                bottom: 10,
                child: _MediaChip(
                    icon: Icons.fitness_center, label: widget.equipment),
              ),
            // The "Demo loop" affordance only makes sense over real footage — shown only while the
            // photo page is active (there is no demo media in the free layer).
            if (photoActive)
              const Positioned(
                right: 10,
                bottom: 10,
                child: _MediaChip(icon: Icons.play_arrow, label: 'Demo loop'),
              ),
            // Swipe affordance — page dots in a translucent pill so they read over both the photo and
            // the light-grey map background.
            if (pages.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: _CarouselDots(count: pages.length, active: activePage),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(GbColors gb) => ColoredBox(
        color: gb.grey0,
        child: Center(
          child: Icon(Icons.fitness_center, size: 40, color: gb.grey400),
        ),
      );
}

/// Page-indicator dots for the [_MediaSlot] carousel — wrapped in a translucent dark pill so the white
/// dots stay legible over both the photo and the light-grey muscle-map page.
class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppPalette.grey900.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : 5),
                width: i == active ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Overlaid translucent chip on the media slot (equipment / demo).
class _MediaChip extends StatelessWidget {
  const _MediaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppPalette.grey900.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// "TARGETS" label + muscle pills (primary tinted, secondary neutral, each with a leading dot).
// Fine muscle-slug → human label for the TARGETS pills (e.g. `biceps` → "Biceps", `gluteal` → "Glutes").
const Map<String, String> _kMuscleLabels = {
  'chest': 'Chest', 'obliques': 'Obliques', 'abs': 'Abs', 'biceps': 'Biceps',
  'triceps': 'Triceps', 'forearm': 'Forearms', 'trapezius': 'Traps',
  'deltoids': 'Delts', 'upper-back': 'Upper back', 'lower-back': 'Lower back',
  'adductors': 'Adductors', 'quadriceps': 'Quads', 'tibialis': 'Shins',
  'calves': 'Calves', 'hamstring': 'Hamstrings', 'gluteal': 'Glutes',
};
String _muscleLabel(String slug) => _kMuscleLabels[slug] ?? _titleCase(slug);

class _TargetsRow extends StatelessWidget {
  const _TargetsRow({
    required this.primary,
    required this.secondary,
    this.detailedPrimary = const [],
    this.detailedSecondary = const [],
  });
  final List<String> primary;
  final List<String> secondary;

  /// Specific worked muscles — preferred over the coarse [primary]/[secondary] group names when present, so
  /// the pills read "Biceps"/"Hamstrings" (what the map highlights) instead of "Arms"/"Legs".
  final List<String> detailedPrimary;
  final List<String> detailedSecondary;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final useDetailed =
        detailedPrimary.isNotEmpty || detailedSecondary.isNotEmpty;
    final primaryLabels =
        useDetailed ? detailedPrimary.map(_muscleLabel).toList() : primary;
    final secondaryLabels =
        useDetailed ? detailedSecondary.map(_muscleLabel).toList() : secondary;
    if (primaryLabels.isEmpty && secondaryLabels.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('TARGETS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: gb.grey400)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in primaryLabels)
                  _MusclePill(label: m, isPrimary: true),
                for (final m in secondaryLabels)
                  _MusclePill(label: m, isPrimary: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MusclePill extends StatelessWidget {
  const _MusclePill({required this.label, required this.isPrimary});
  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isPrimary ? _kPrimaryTint : gb.grey0,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: isPrimary ? gb.primary25 : gb.borderCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isPrimary ? gb.primary500 : _kGrey300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? gb.primary700 : gb.grey600)),
        ],
      ),
    );
  }
}

/// The tab bar + scrolling tab body.
class _TabbedGuide extends StatelessWidget {
  const _TabbedGuide({
    required this.guide,
    required this.tab,
    required this.onTab,
    required this.scroll,
  });
  final CoachGuide guide;
  final _GuideTab tab;
  final ValueChanged<_GuideTab> onTab;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar — content-width pills (design vocabulary). A Wrap keeps them on one row when they
        // fit (the common case) and wraps gracefully instead of clipping on narrow screens / wide fonts.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final t in _GuideTab.values)
                _TabPill(
                  label: t.label,
                  selected: t == tab,
                  onTap: () => onTab(t),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (tab) {
            _GuideTab.steps => _StepsBody(guide: guide, scroll: scroll),
            _GuideTab.setup => _SetupBody(guide: guide, scroll: scroll),
            _GuideTab.cues => _CuesBody(guide: guide, scroll: scroll),
            _GuideTab.mistakes => _MistakesBody(guide: guide, scroll: scroll),
          },
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        // No `alignment` — inside a Wrap (bounded width) it would expand the pill to full width.
        // Padding + a min-size Row keep the pill hugging its label.
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? gb.primary500 : gb.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: selected ? gb.primary500 : gb.borderCard, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : gb.grey600)),
          ],
        ),
      ),
    );
  }
}

/// Steps tab — optional Tempo / Breathing info chips, then a connected numbered list.
class _StepsBody extends StatelessWidget {
  const _StepsBody({required this.guide, required this.scroll});
  final CoachGuide guide;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final hasMeta = guide.tempo != null || guide.breathing != null;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        if (hasMeta) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (guide.tempo != null)
                  Expanded(
                      child: _InfoChip(
                          icon: Icons.timer_outlined,
                          label: 'TEMPO',
                          value: guide.tempo!)),
                if (guide.tempo != null && guide.breathing != null)
                  const SizedBox(width: 8),
                if (guide.breathing != null)
                  Expanded(
                      child: _InfoChip(
                          icon: Icons.sync,
                          label: 'BREATHING',
                          value: guide.breathing!)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (guide.steps.isEmpty)
          const _EmptyTabNote(
              text: 'No step-by-step is authored for this exercise yet.')
        else
          _NumberedSteps(
            steps: guide.steps,
            badgeColor: gb.primary500,
            badgeTextColor: Colors.white,
            badgeBorder: null,
            lineColor: gb.primary25,
          ),
      ],
    );
  }
}

/// Setup tab — connected numbered list with soft (tinted) badges.
class _SetupBody extends StatelessWidget {
  const _SetupBody({required this.guide, required this.scroll});
  final CoachGuide guide;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        if (guide.setup.isEmpty)
          const _EmptyTabNote(text: 'No setup notes for this exercise yet.')
        else
          _NumberedSteps(
            steps: guide.setup,
            badgeColor: _kPrimaryTint,
            badgeTextColor: gb.primary700,
            badgeBorder: gb.primary25,
            lineColor: gb.grey25,
          ),
      ],
    );
  }
}

/// Cues tab — green-check bullet list.
class _CuesBody extends StatelessWidget {
  const _CuesBody({required this.guide, required this.scroll});
  final CoachGuide guide;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        if (guide.cues.isEmpty)
          const _EmptyTabNote(text: 'No coaching cues for this exercise yet.')
        else
          for (final c in guide.cues)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IconBullet(
                icon: Icons.check,
                bg: gb.success0,
                border: gb.success50,
                iconColor: gb.success,
                text: c,
              ),
            ),
      ],
    );
  }
}

/// Mistakes tab — red-✕ bullet list, then a yellow safety callout.
class _MistakesBody extends StatelessWidget {
  const _MistakesBody({required this.guide, required this.scroll});
  final CoachGuide guide;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final hasAny = guide.mistakes.isNotEmpty || guide.safety != null;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        if (!hasAny)
          const _EmptyTabNote(
              text: 'No common mistakes flagged for this exercise yet.'),
        for (final m in guide.mistakes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _IconBullet(
              icon: Icons.close,
              bg: gb.danger0,
              border: _kError50,
              iconColor: _kError200,
              text: m,
            ),
          ),
        if (guide.safety != null) ...[
          if (guide.mistakes.isNotEmpty) const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: gb.warning0,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: _kWarning50),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt, size: 16, color: gb.warning200),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(guide.safety!,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: gb.warning300)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Connected numbered step list (white-ring badges over a vertical rail).
class _NumberedSteps extends StatelessWidget {
  const _NumberedSteps({
    required this.steps,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeBorder,
    required this.lineColor,
  });
  final List<String> steps;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color? badgeBorder;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Per-row connector: each badge draws the rail segment BELOW it down to the next badge. The last
    // row draws none, so there's no stray stub past the final step.
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                          border: badgeBorder != null
                              ? Border.all(color: badgeBorder!)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: badgeTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (i != steps.length - 1)
                        Expanded(child: Container(width: 2, color: lineColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: 3, bottom: i == steps.length - 1 ? 0 : 16),
                    child: Text(steps[i],
                        style: TextStyle(
                            fontSize: 14.5,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                            color: gb.grey900)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A coloured icon-tile bullet (cues = green check, mistakes = red ✕).
class _IconBullet extends StatelessWidget {
  const _IconBullet({
    required this.icon,
    required this.bg,
    required this.border,
    required this.iconColor,
    required this.text,
  });
  final IconData icon;
  final Color bg;
  final Color border;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: gb.grey900)),
          ),
        ),
      ],
    );
  }
}

/// Tempo / Breathing info card on the Steps tab.
class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: gb.grey0,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: gb.borderCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: gb.primary600),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: gb.grey400)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: gb.grey900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTabNote extends StatelessWidget {
  const _EmptyTabNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: gb.grey400, height: 1.5)),
      ),
    );
  }
}

/// Edge case — substituted / ad-hoc movement with no authored guide and no API content.
class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody({required this.exerciseName, required this.scroll});
  final String exerciseName;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
          16, 18, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          decoration: BoxDecoration(
            color: gb.grey0,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: gb.borderField),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gb.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gb.borderCard),
                ),
                child: Icon(Icons.edit_outlined, size: 20, color: gb.grey400),
              ),
              const SizedBox(height: 12),
              Text('Full guide coming soon',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: gb.grey900)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'We don’t have a step-by-step for $exerciseName yet. '
                  'Here’s what it trains — your form stays your call this session.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: gb.grey500, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideErrorBody extends StatelessWidget {
  const _GuideErrorBody({required this.scroll});
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Text('Couldn’t load this guide — check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: gb.grey500, height: 1.5)),
      ],
    );
  }
}

// Design tokens sourced from the [AppPalette] primitives (single source of truth for the
// design's tokens.css hex). Aliased here for the call-sites below; not surfaced on GbColors.
const Color _kPrimaryTint =
    AppPalette.primaryTint; // --gb-primary-tint (0xFFE6F0FF)
const Color _kGrey300 = AppPalette.grey300; // --inv-grey-300 (0xFF98A1B0)
const Color _kError50 = AppPalette.error50; // --inv-error-50 (0xFFF28E8E)
const Color _kError200 = AppPalette.error200; // --inv-error-200 (0xFFA32020)
const Color _kWarning50 = AppPalette.warning50; // --inv-warning-50 (0xFFFBD582)
