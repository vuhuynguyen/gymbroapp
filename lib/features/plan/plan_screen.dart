import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/plan_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import '../session/start_actions.dart';
import 'plan_providers.dart';

/// The trainee's assigned plan(s), read-only. Server-side visibility (Guided hide flags) is already
/// applied to the detail payload — this screen renders whatever the API returns and surfaces the
/// redaction states. Blind plans are locked here; workouts reveal at session start.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  int _planIndex = 0;
  int _dayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(assignedPlansProvider);

    return Scaffold(
      body: Column(
        children: [
          GbAppHeader(
            title: 'Plan',
            actions: [
              GbBellButton(
                  onTap: () => showInfoSnack(context, 'No notifications yet'))
            ],
          ),
          Expanded(
            child: AsyncValueView(
              value: plans,
              onRetry: () async => ref.invalidate(assignedPlansProvider),
              loading: const GbSkeletonList(count: 4),
              data: (assigned) {
                if (assigned.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No assigned plans',
                    subtitle:
                        'When a coach assigns you a plan, it appears here.',
                    action: GbButton(
                      label: 'Join a coach',
                      icon: Icons.confirmation_number_outlined,
                      variant: GbButtonVariant.outlined,
                      onPressed: () => context.push('/join'),
                    ),
                  );
                }
                final index = _planIndex.clamp(0, assigned.length - 1);
                final current = assigned[index];
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(assignedPlansProvider);
                    await ref.read(assignedPlansProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                        AppSpacing.gap, AppSpacing.screenH, 100),
                    children: [
                      if (assigned.length > 1) ...[
                        _PlanPicker(
                          plans: assigned,
                          value: index,
                          onChanged: (v) => setState(() {
                            _planIndex = v;
                            _dayIndex = 0;
                          }),
                        ),
                        const SizedBox(height: AppSpacing.gap),
                      ],
                      _ProgramHero(plan: current),
                      const SizedBox(height: AppSpacing.gap),
                      if (current.isBlind)
                        const _BlindLockCard()
                      else
                        _PlanBody(
                          planId: current.assignment.planId,
                          assignmentId: current.assignment.id,
                          dayIndex: _dayIndex,
                          onDay: (i) => setState(() => _dayIndex = i),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-plan selector (only shown when the trainee has more than one active assignment).
class _PlanPicker extends StatelessWidget {
  const _PlanPicker(
      {required this.plans, required this.value, required this.onChanged});
  final List<AssignedPlan> plans;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: gb.grey400),
          style: AppText.rowTitle.copyWith(color: gb.ink),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            labelText: 'Plan',
            labelStyle: TextStyle(color: gb.grey500),
          ),
          items: [
            for (var i = 0; i < plans.length; i++)
              DropdownMenuItem(
                  value: i,
                  child: Text(plans[i].displayName,
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => onChanged(v ?? 0),
        ),
      ),
    );
  }
}

/// Gradient program hero — "CURRENT PROGRAM" eyebrow, the plan name, and a Week/Days/Visibility stat row.
class _ProgramHero extends StatelessWidget {
  const _ProgramHero({required this.plan});
  final AssignedPlan plan;

  int _currentWeek() {
    final start = plan.assignment.startDate;
    if (start == null) return 1;
    final days = DateTime.now().difference(start).inDays;
    if (days < 0) return 1;
    return (days ~/ 7) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return GbHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Current program', color: AppPalette.primary50),
          const SizedBox(height: AppSpacing.xxs + 1),
          Text(plan.displayName,
              style: AppText.heroTitle
                  .copyWith(color: Colors.white, fontSize: 21)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _HeroStat(label: 'Week', value: 'Wk ${_currentWeek()}'),
              const SizedBox(width: AppSpacing.lg - 4),
              _HeroStat(
                  label: 'Days',
                  value: '${plan.assignment.frequencyDaysPerWeek}/wk'),
              const SizedBox(width: AppSpacing.lg - 4),
              _HeroStat(label: 'Visibility', value: plan.visibility.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)
                .tabular),
        const SizedBox(height: 2),
        Eyebrow(label, color: Colors.white.withValues(alpha: 0.66)),
      ],
    );
  }
}

/// Lock card shown for Blind plans — workouts stay hidden until the session starts.
class _BlindLockCard extends StatelessWidget {
  const _BlindLockCard();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      child: Row(
        children: [
          GbIconTile(
              background: gb.grey25,
              child: Icon(Icons.lock_outline,
                  size: AppSizes.iconXl, color: gb.grey600)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Blind plan', style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text('Workouts are hidden until you start the session.',
                    style:
                        AppText.meta.copyWith(color: gb.grey500, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody(
      {required this.planId,
      required this.assignmentId,
      required this.dayIndex,
      required this.onDay});
  final String planId;
  final String assignmentId;
  final int dayIndex;
  final ValueChanged<int> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(planDetailProvider(planId));
    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: ErrorRetry(
            message: e.toString(),
            onRetry: () async => ref.invalidate(planDetailProvider(planId))),
      ),
      data: (plan) {
        if (plan.workouts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No workouts yet',
              subtitle: 'This plan has no workouts assigned.',
            ),
          );
        }
        final day = dayIndex.clamp(0, plan.workouts.length - 1);
        final workout = plan.workouts[day];
        final gb = context.gb;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Horizontal day-chip strip.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < plan.workouts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: GbChip(
                        label: plan.workouts[i].name,
                        selected: i == day,
                        onTap: () => onDay(i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            // Workout name + plan source tag + exercise count.
            Row(
              children: [
                Flexible(
                  child: Text(workout.name,
                      style: AppText.sectionTitle.copyWith(fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.xs),
                const SourceTag(SessionSource.fromAssignment, small: true),
                const Spacer(),
                Text(
                  '${workout.exercises.length} exercise${workout.exercises.length == 1 ? '' : 's'}',
                  style: AppText.meta.copyWith(color: gb.grey400),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Per-workout Start CTA.
            GbButton(
              label: 'Start ${workout.name}',
              icon: Icons.play_arrow,
              size: GbButtonSize.sm,
              full: true,
              onPressed: () => startFromAssignment(
                context,
                ref,
                planAssignmentId: assignmentId,
                plannedWorkoutId: workout.id,
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            // Read-only exercise rows.
            for (var i = 0; i < workout.exercises.length; i++) ...[
              _ExerciseRow(index: i + 1, exercise: workout.exercises[i]),
              if (i < workout.exercises.length - 1)
                const SizedBox(height: AppSpacing.xs + 1),
            ],
          ],
        );
      },
    );
  }
}

/// One read-only plan exercise row — numbered tile, name, set summary, chevron. Renders the
/// server's redaction states (hidden exercise / targets hidden) exactly as the API delivers them.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.exercise});
  final int index;
  final PlanWorkoutExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final hidden = exercise.exerciseHidden;
    final name =
        hidden ? 'Hidden exercise' : (exercise.exerciseName ?? 'Exercise');
    return GbCard(
      padding: const EdgeInsets.all(AppSpacing.gap),
      child: Row(
        children: [
          GbIconTile(
            background: gb.primary0,
            radius: 11,
            child: Text('$index',
                style: TextStyle(
                        fontSize: AppSizes.iconSm,
                        fontWeight: FontWeight.w800,
                        color: gb.primary700)
                    .tabular),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gb.ink,
                    fontStyle: hidden ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_setSummary(exercise.sets),
                    style: AppText.meta.copyWith(color: gb.grey500).tabular),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right,
              size: AppSizes.iconMd, color: AppPalette.grey300),
        ],
      ),
    );
  }

  static String _setSummary(List<PlanSetDetail> sets) {
    if (sets.isEmpty) return 'No sets';
    final allHidden = sets.every((s) => s.targetsHidden);
    if (allHidden) return '${sets.length} sets · targets hidden';
    final s = sets.last;
    final reps = s.targetReps?.toString() ?? '—';
    final kg = s.targetWeightKg != null
        ? ' @ ${s.targetWeightKg!.toStringAsFixed(0)}kg'
        : '';
    return '${sets.length} × $reps$kg';
  }
}
