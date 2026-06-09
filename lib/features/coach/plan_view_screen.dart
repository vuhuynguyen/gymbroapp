import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/plan_models.dart';
import '../../shared/widgets/widgets.dart';
import '../plan/plan_providers.dart';

/// Read-only plan detail for a coach (Owner sees the full, unredacted plan). Authoring stays in the
/// portal; here a coach reviews structure and can jump to Assign.
class PlanViewScreen extends ConsumerWidget {
  const PlanViewScreen({required this.planId, super.key});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planDetailProvider(planId));
    return Scaffold(
      backgroundColor: context.gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
      body: Column(
        children: [
          GbDetailHeader(title: 'Plan', onLeading: () => context.pop()),
          Expanded(
            child: AsyncValueView(
              value: plan,
              onRetry: () async => ref.invalidate(planDetailProvider(planId)),
              data: (p) => _Body(plan: p, planId: planId),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.plan, required this.planId});
  final WorkoutPlanDetail plan;
  final String planId;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final meta = <String>[
      'v${plan.version}',
      if (plan.workoutsPerWeek != null) '${plan.workoutsPerWeek}×/wk',
      if (plan.durationWeeks != null) '${plan.durationWeeks} wks',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.lg),
      children: [
        Text(plan.name, style: AppText.screenTitle.copyWith(color: gb.ink)),
        const SizedBox(height: AppSpacing.xxs),
        Text(meta.join(' · '), style: TextStyle(fontSize: 13, color: gb.grey500)),
        if (plan.description != null && plan.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(plan.description!, style: TextStyle(fontSize: 14, height: 1.5, color: gb.grey700)),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final w in plan.workouts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm - 2),
            child: _WorkoutCard(workout: w),
          ),
        const SizedBox(height: AppSpacing.xs),
        GbButton(
          label: 'Assign to a client',
          icon: Icons.person_add_alt,
          full: true,
          onPressed: () => context.push('/assign/$planId'),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});
  final PlanWorkoutDetail workout;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(workout.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text('${workout.exercises.length} exercises',
                  style: TextStyle(fontSize: 12, color: gb.grey400)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < workout.exercises.length; i++) ...[
            if (i > 0) Divider(height: 1, color: gb.grey25),
            _ExerciseRow(index: i + 1, exercise: workout.exercises[i]),
          ],
        ],
      ),
    );
  }
}

/// Numbered read-only exercise row — index badge, name (or redacted), set summary.
class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.exercise});
  final int index;
  final PlanWorkoutExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final hidden = exercise.exerciseHidden;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: gb.grey0, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('$index',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: gb.grey500).tabular),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hidden) ...[
                      Icon(Icons.lock_outline, size: AppSizes.iconSm, color: gb.grey400),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        hidden ? 'Hidden exercise' : (exercise.exerciseName ?? 'Exercise'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hidden ? gb.grey400 : gb.grey900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _SetSummary(sets: exercise.sets),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders prescribed sets as compact meta pills, respecting Guided redaction (targets hidden).
class _SetSummary extends StatelessWidget {
  const _SetSummary({required this.sets});
  final List<PlanSetDetail> sets;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    if (sets.isEmpty) {
      return Text('No sets', style: TextStyle(fontSize: 12, color: gb.grey400));
    }
    return Wrap(
      spacing: AppSpacing.xs - 2,
      runSpacing: AppSpacing.xs - 2,
      children: [
        for (final s in sets) GbMetaPill(_label(s)),
      ],
    );
  }

  static String _label(PlanSetDetail s) {
    if (s.targetsHidden) return '${s.setType.name} · logged live';
    final kg = s.targetWeightKg != null ? '${s.targetWeightKg!.toStringAsFixed(0)}kg × ' : '';
    final reps = s.targetReps?.toString() ?? '—';
    final rpe = s.targetRpe != null ? ' @${s.targetRpe}' : '';
    return '$kg$reps$rpe';
  }
}
