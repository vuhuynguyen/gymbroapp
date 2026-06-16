import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/plan_models.dart';
import '../../domain/enums.dart';
import '../../shared/superset/superset_grouping.dart';
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
      backgroundColor: context
          .gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
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

    // The primary CTA is pinned to the bottom (always reachable) rather than trailing a long workout
    // list, so a coach can assign without scrolling to the end.
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                AppSpacing.md, AppSpacing.screenH, AppSpacing.lg),
            children: [
              Text(plan.name,
                  style: AppText.screenTitle.copyWith(color: gb.ink)),
              const SizedBox(height: AppSpacing.xxs),
              Text(meta.join(' · '),
                  style: TextStyle(fontSize: 13, color: gb.grey500)),
              if (plan.description != null && plan.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(plan.description!,
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: gb.grey700)),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final w in plan.workouts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm - 2),
                  child: _WorkoutCard(workout: w),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
              color: gb.card,
              border: Border(top: BorderSide(color: gb.borderCard))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                  AppSpacing.sm, AppSpacing.screenH, AppSpacing.sm),
              child: GbButton(
                label: 'Assign to a client',
                icon: Icons.person_add_alt,
                full: true,
                onPressed: () => context.push('/assign/$planId'),
              ),
            ),
          ),
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
    // Superset grouping (A1/A2 …) so a coach reviewing the plan sees which exercises are paired.
    final ssTags = supersetTags([
      for (final e in workout.exercises)
        SupersetMember(
            id: e.id,
            order: e.order,
            groupId: e.supersetGroupId,
            name: e.exerciseName),
    ]);
    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(workout.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text('${workout.exercises.length} exercises',
                  style: TextStyle(fontSize: 12, color: gb.grey400)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < workout.exercises.length; i++) ...[
            if (i > 0) Divider(height: 1, color: gb.grey25),
            _ExerciseRow(
              index: i + 1,
              exercise: workout.exercises[i],
              supersetTag: ssTags[workout.exercises[i].id],
            ),
          ],
        ],
      ),
    );
  }
}

/// Numbered read-only exercise row — collapsed by default (number · name · set count); tap to reveal the
/// prescribed set pills. Inline collapse keeps the workout-card grouping intact (no nested cards).
class _ExerciseRow extends StatefulWidget {
  const _ExerciseRow(
      {required this.index, required this.exercise, this.supersetTag});
  final int index;
  final PlanWorkoutExerciseDetail exercise;
  final SupersetTag? supersetTag;

  @override
  State<_ExerciseRow> createState() => _ExerciseRowState();
}

class _ExerciseRowState extends State<_ExerciseRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final exercise = widget.exercise;
    final hidden = exercise.exerciseHidden;
    final count = exercise.sets.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      color: gb.grey0, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text('${widget.index}',
                      style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: gb.grey500)
                          .tabular),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (hidden) ...[
                  Icon(Icons.lock_outline,
                      size: AppSizes.iconSm, color: gb.grey400),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    hidden
                        ? 'Hidden exercise'
                        : (exercise.exerciseName ?? 'Exercise'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hidden ? gb.grey400 : gb.grey900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.supersetTag != null) ...[
                  const SizedBox(width: 6),
                  SupersetChip(widget.supersetTag!),
                ],
                const SizedBox(width: AppSpacing.xs),
                Text('$count set${count == 1 ? '' : 's'}',
                    style: AppText.meta.copyWith(color: gb.grey400)),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: AppDurations.base,
                  child: Icon(Icons.chevron_right,
                      size: AppSizes.iconMd, color: gb.grey400),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppDurations.base,
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.xs, left: 26 + AppSpacing.sm),
                    child: _SetSummary(sets: exercise.sets),
                  )
                : const SizedBox(width: double.infinity),
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
        for (final (i, s) in sets.indexed) GbMetaPill(_label(i + 1, s)),
      ],
    );
  }

  /// Leads with the set number + type, then targets, e.g. "1 · Warmup · 30kg × 12 @7".
  static String _label(int number, PlanSetDetail s) {
    final type = PerformedSetType.parse(s.setType.wire).label;
    if (s.targetsHidden) return '$number · $type · logged live';
    final kg = s.targetWeightKg != null
        ? '${s.targetWeightKg!.toStringAsFixed(0)}kg × '
        : '';
    final reps = s.targetReps?.toString() ?? '—';
    final rpe = s.targetRpe != null ? ' @${s.targetRpe}' : '';
    return '$number · $type · $kg$reps$rpe';
  }
}
