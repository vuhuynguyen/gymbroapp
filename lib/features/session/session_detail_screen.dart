import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/session_models.dart';
import '../../domain/enums.dart';
import '../../domain/session_metrics.dart';
import '../../shared/widgets/widgets.dart';
import '../log/log_providers.dart';
import 'start_actions.dart';

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
                return Column(
                  children: [
                    Expanded(child: _Body(detail: d, fromFinish: fromFinish)),
                    if (canRepeat)
                      _RepeatBar(
                        onRepeat: () => startFromAssignment(
                          context,
                          ref,
                          planAssignmentId: d.planAssignmentId!,
                          plannedWorkoutId: d.plannedWorkoutId!,
                        ),
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

/// Pinned footer with the "Repeat workout" CTA (design Session Detail action bar).
class _RepeatBar extends StatelessWidget {
  const _RepeatBar({required this.onRepeat});
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      decoration: BoxDecoration(
          color: gb.card,
          border: Border(top: BorderSide(color: gb.borderCard))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm,
              AppSpacing.screenH, AppSpacing.sm),
          child: GbButton(
              label: 'Repeat workout',
              icon: Icons.play_arrow,
              full: true,
              onPressed: onRepeat),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail, required this.fromFinish});
  final SessionDetail detail;
  final bool fromFinish;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final d = detail;
    final prExerciseIds = d.prs.map((p) => p.exerciseId).toSet();
    final totalSets = d.exercises.fold<int>(0, (a, e) => a + e.sets.length);
    final at = d.startedAt ?? d.completedAt;

    final metaParts = <String>[
      if (d.programName != null && d.programName!.isNotEmpty) d.programName!,
      if (d.planWeek != null) 'Week ${d.planWeek}',
      if (at != null) _dateLabel(at),
      if (at != null) _timeLabel(at),
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

        // Stat grid — row 1: duration, volume; row 2: sets, avg RPE, PRs.
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
              child: GbStatTile(
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
              child: GbStatTile(
                icon: Icons.layers_outlined,
                label: 'Sets',
                value: '$totalSets',
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: GbStatTile(
                icon: Icons.local_fire_department_outlined,
                label: 'Avg RPE',
                value: d.rpeOverall != null ? '${d.rpeOverall}' : '—',
                unit: d.rpeOverall != null ? '/10' : null,
                accent: gb.amber,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: GbStatTile(
                icon: Icons.emoji_events_outlined,
                label: 'PRs',
                value: '${d.prs.length}',
                accent: gb.amber,
              ),
            ),
          ],
        ),

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
              ],
            ),
          ),
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
String _dateLabel(DateTime d) {
  final l = d.toLocal();
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
String _timeLabel(DateTime d) {
  final l = d.toLocal();
  final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  final ap = l.hour < 12 ? 'am' : 'pm';
  return '$h12:$m$ap';
}
