import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/exercise_models.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session_metrics.dart';
import '../../shared/widgets/widgets.dart';
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
  double _weight = 0;
  int _reps = 0;
  PerformedSetType _entryType = PerformedSetType.working;

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
    final snapSet = _snapshotSetFor(st, ex, ex.sets.length);
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    _weight = last?.weightKg ?? snapSet?.targetWeightKg ?? 0;
    _reps = last?.reps ?? snapSet?.targetReps ?? 0;
    _entryType = last?.setType ??
        (snapSet != null
            ? PerformedSetType.parse(snapSet.setType.wire)
            : PerformedSetType.working);
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

  Future<void> _logSet(String exerciseId) async {
    if (_reps <= 0 && _weight <= 0) {
      showInfoSnack(context, 'Enter your reps (and weight) to log the set.');
      return;
    }
    await _ctrl.logSet(exerciseId,
        reps: _reps, weightKg: _weight, setType: _entryType);
  }

  Future<void> _confirmDeleteSet(String exerciseId, PerformedSet set) async {
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
    if (ok == true) await _ctrl.deleteSet(exerciseId, set.id);
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
    final id = ref.read(liveSessionControllerProvider).session?.sessionId;
    final done = await _ctrl.complete();
    if (done && mounted && id != null) {
      context.pushReplacement('/session-detail/$id?finished=true&me=1');
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

    return Scaffold(
      body: Column(
        children: [
          _Header(
            topInset: MediaQuery.of(context).padding.top,
            title: session.snapshot?.workoutName ?? 'Workout',
            subtitle: session.source == SessionSource.fromAssignment
                ? 'Plan workout'
                : 'Ad-hoc session',
            logged: logged,
            total: total,
            hasTarget: totalPlanned > 0,
            onAbandon: _confirmAbandon,
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
                        catalog: catalog[ex.exerciseId],
                        snapshotSets: _snapshotSetsFor(st, ex),
                        weight: _weight,
                        reps: _reps,
                        entryType: _entryType,
                        busy: st.busy,
                        onWeight: (v) => setState(() => _weight = v.toDouble()),
                        onReps: (v) => setState(() => _reps = v.toInt()),
                        onSetType: (t) => setState(() => _entryType = t),
                        onLog: () => _logSet(ex.id),
                        onDeleteSet: (s) => _confirmDeleteSet(ex.id, s),
                        onMenu: () => _openExerciseMenu(ex),
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      Center(
                        child: Text(
                            'Logged values save to your session automatically.',
                            style: AppText.meta
                                .copyWith(color: context.gb.grey400)),
                      ),
                    ],
                  ),
          ),
          if (st.rest != null)
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
              onFinish: _finish,
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
  final VoidCallback onAbandon;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pct = hasTarget && total > 0 ? (logged / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      decoration: const BoxDecoration(gradient: GbColors.heroGradient),
      padding: EdgeInsets.fromLTRB(8, topInset + 6, 8, 14),
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
              GbGlassButton(
                  icon: Icons.close,
                  onTap: onAbandon,
                  semanticLabel: 'Abandon workout'),
            ],
          ),
          // Plan-only progress bar (full width). The elapsed timer moved to the exercise-pager row to
          // save vertical space, so ad-hoc sessions now get a compact single-row header.
          if (hasTarget) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
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
    required this.catalog,
    required this.snapshotSets,
    required this.weight,
    required this.reps,
    required this.entryType,
    required this.busy,
    required this.onWeight,
    required this.onReps,
    required this.onSetType,
    required this.onLog,
    required this.onDeleteSet,
    required this.onMenu,
  });

  final PerformedExercise exercise;
  final ExerciseSummary? catalog;
  final List<SessionSnapshotSet> snapshotSets;
  final double weight;
  final int reps;
  final PerformedSetType entryType;
  final bool busy;
  final ValueChanged<num> onWeight;
  final ValueChanged<num> onReps;
  final ValueChanged<PerformedSetType> onSetType;
  final VoidCallback onLog;
  final ValueChanged<PerformedSet> onDeleteSet;
  final VoidCallback onMenu;

  String? _metaTargets() {
    final src = snapshotSets.isNotEmpty
        ? snapshotSets
            .map((s) => (reps: s.targetReps, kg: s.targetWeightKg))
            .toList()
        : exercise.sets.map((s) => (reps: s.reps, kg: s.weightKg)).toList();
    if (src.isEmpty) return null;
    final last = src.last;
    final repsStr = last.reps?.toString() ?? '—';
    final kgStr = last.kg != null ? ' @ ${last.kg!.toStringAsFixed(0)}kg' : '';
    return '${src.length} × $repsStr$kgStr';
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final name = exercise.exerciseName ?? 'Exercise ${exercise.order}';
    final isSkipped = exercise.status == ExercisePerformStatus.skipped;
    final targets = _metaTargets();
    // Per-exercise set count (logged vs planned, or just the running count when ad-hoc).
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                          child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [for (final p in pills) GbMetaPill(p)]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GbIconButton(
                    icon: Icons.more_horiz,
                    onTap: onMenu,
                    semanticLabel: 'More options'),
              ],
            ),
          ),
          Divider(height: 1, color: gb.borderCard),
          // Sets
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final s in exercise.sets)
                  _LoggedSetRow(set: s, onDelete: () => onDeleteSet(s)),
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
                      target: snapshotSets.length >= exercise.sets.length + 1
                          ? snapshotSets[exercise.sets.length]
                          : null,
                      weight: weight,
                      reps: reps,
                      setType: entryType,
                      busy: busy,
                      onWeight: onWeight,
                      onReps: onReps,
                      onSetType: onSetType,
                      onLog: onLog,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A logged (done) set row — design layout: check + type on the left, weight×reps + e1RM right.
/// Long-press to delete (the design keeps the row clean — no inline trash).
class _LoggedSetRow extends StatelessWidget {
  const _LoggedSetRow({required this.set, required this.onDelete});
  final PerformedSet set;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final e1rm =
        set.estimatedOneRepMaxKg ?? epleyOneRepMax(set.weightKg, set.reps);
    return InkWell(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration:
                  BoxDecoration(color: gb.success0, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.check, size: 15, color: gb.success),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text(set.setType.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: gb.grey500)),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_fmtKg(set.weightKg)} × ${set.reps ?? '—'}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: gb.grey700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                if (set.setType == PerformedSetType.working && e1rm != null)
                  Text('e1RM ${e1rm.toStringAsFixed(1)}kg',
                      style: TextStyle(
                          fontSize: 11,
                          color: gb.grey500,
                          fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtKg(double? kg) =>
      kg == null ? '—' : '${kg % 1 == 0 ? kg.toInt() : kg}kg';
}

/// The highlighted current-set entry card (design): set chip + set-type selector + target, big
/// weight/reps steppers, Epley e1RM, gradient Log-set button.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.setNumber,
    required this.target,
    required this.weight,
    required this.reps,
    required this.setType,
    required this.busy,
    required this.onWeight,
    required this.onReps,
    required this.onSetType,
    required this.onLog,
  });
  final int setNumber;
  final SessionSnapshotSet? target;
  final double weight;
  final int reps;
  final PerformedSetType setType;
  final bool busy;
  final ValueChanged<num> onWeight;
  final ValueChanged<num> onReps;
  final ValueChanged<PerformedSetType> onSetType;
  final VoidCallback onLog;

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
    final e1rm = epleyOneRepMax(weight, reps);
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
              if (target != null &&
                  (target!.targetWeightKg != null ||
                      target!.targetReps != null))
                Text(
                    'Target ${target!.targetWeightKg?.toStringAsFixed(0) ?? '—'}kg × ${target!.targetReps ?? '—'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: gb.grey500,
                        fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                    child: GbStepper(
                        label: 'WEIGHT',
                        semanticLabel: 'Weight',
                        value: weight,
                        unit: 'kg',
                        step: 2.5,
                        onChanged: onWeight)),
                const SizedBox(width: 6),
                Container(
                    width: 1, color: gb.primary500.withValues(alpha: 0.18)),
                const SizedBox(width: 6),
                Expanded(
                    child: GbStepper(
                        label: 'REPS',
                        semanticLabel: 'Reps',
                        value: reps,
                        step: 1,
                        onChanged: onReps)),
              ],
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
          FilledButton.icon(
            // A logged set needs at least 1 rep (weight 0 stays valid — bodyweight movements).
            onPressed: (busy || reps <= 0) ? null : onLog,
            icon: const Icon(Icons.check),
            label: Text(reps <= 0 ? 'Enter reps to log' : 'Log set'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
  });
  final bool canPrev;
  final bool isLast;
  final bool busy;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onFinish;

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
              onTap: onPrev,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Expanded(
            child: isLast
                ? GbButton(
                    label: 'Finish workout',
                    icon: Icons.flag,
                    full: true,
                    busy: busy,
                    onPressed: onFinish,
                  )
                : GbButton(
                    label: 'Next exercise',
                    iconRight: Icons.chevron_right,
                    full: true,
                    onPressed: onNext,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Exercise-catalog picker (substitute / add) — search + muscle filter over the global catalog.
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
  String _muscle = 'All';

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

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => FutureBuilder<List<ExerciseSummary>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return ErrorRetry(message: snap.error.toString());
          final all = snap.data ?? const [];
          final muscles = <String>{
            'All',
            for (final e in all)
              if (e.muscleGroup.isNotEmpty) e.muscleGroup
          };
          final filtered = all.where((e) {
            final byMuscle = _muscle == 'All' || e.muscleGroup == _muscle;
            final byQuery = _query.isEmpty ||
                e.name.toLowerCase().contains(_query.toLowerCase());
            return byMuscle && byQuery;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GbSheetHeader(
                    title: widget.title,
                    subtitle:
                        '${widget.title == 'Substitute' ? 'Replace' : 'Add a movement to'} this session.',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: GbSearchField(
                  controller: _search,
                  hint: 'Search exercises…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  children: [
                    for (final m in muscles)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GbChip(
                            label: m,
                            selected: _muscle == m,
                            onTap: () => setState(() => _muscle = m)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
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
                    return GbTappableRow(
                      onTap: () => widget.onPick(e),
                      leading: GbIconTile(
                          background: gb.grey0,
                          child: Icon(Icons.fitness_center,
                              size: AppSizes.iconXl, color: gb.grey500)),
                      title: e.name,
                      subtitle: meta.isEmpty ? null : meta,
                      trailing: GbIconTile(
                        size: 30,
                        radius: AppRadius.sm - 4,
                        background: gb.primary0,
                        child: Icon(Icons.add,
                            size: AppSizes.iconLg, color: gb.primary600),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
