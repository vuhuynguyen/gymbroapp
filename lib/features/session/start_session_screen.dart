import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/plan_models.dart';
import '../../shared/widgets/widgets.dart';
import '../plan/plan_providers.dart';
import 'start_actions.dart';

/// Start a workout FROM a plan: pick an active assignment → a workout (day). The chosen
/// `planAssignmentId` + `plannedWorkoutId` drive the server-side snapshot (unless Blind). Replaces
/// itself with the live session on start.
class StartSessionScreen extends ConsumerWidget {
  const StartSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(assignedPlansProvider);
    return Scaffold(
      backgroundColor: context.gb.canvas,
      body: Column(
        children: [
          GbDetailHeader(
            title: 'Start a workout',
            onLeading: () => context.pop(),
          ),
          Expanded(
            child: AsyncValueView(
              value: plans,
              onRetry: () async => ref.invalidate(assignedPlansProvider),
              loading: const GbSkeletonList(count: 4, itemHeight: 76),
              data: (assigned) {
                if (assigned.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No active plans',
                    subtitle: "A coach hasn't assigned you a plan yet, or yours are paused.",
                    action: GbButton(
                      label: 'Back to Log',
                      icon: Icons.arrow_back,
                      variant: GbButtonVariant.outlined,
                      severity: GbButtonSeverity.secondary,
                      onPressed: () => context.go('/log'),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, AppSpacing.xl),
                  children: [
                    Text(
                      'Pick one of your active assignments, then choose a workout to begin.',
                      style: AppText.body.copyWith(color: context.gb.grey500),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('YOUR ASSIGNMENTS',
                        style:
                            AppText.eyebrow.copyWith(color: context.gb.grey400, letterSpacing: 0.7)),
                    const SizedBox(height: AppSpacing.xs),
                    for (final a in assigned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                        child: _AssignmentCard(plan: a),
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

/// One assignment as an expandable card: header (bolt tile · plan name + visibility · frequency)
/// that toggles open to reveal the plan's workouts (days). Blind plans show a reveal note.
class _AssignmentCard extends StatefulWidget {
  const _AssignmentCard({required this.plan});
  final AssignedPlan plan;

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final a = widget.plan;
    return GbCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: AppRadius.brMd,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + 1),
              child: Row(
                children: [
                  GbIconTile(child: Icon(Icons.bolt, size: 21, color: gb.primary600)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(a.displayName,
                                  overflow: TextOverflow.ellipsis, style: AppText.rowTitle),
                            ),
                            const SizedBox(width: AppSpacing.xs - 1),
                            VisBadge(a.visibility),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.assignment.frequencyDaysPerWeek}×/week · ${a.visibility.label} visibility',
                          style: AppText.meta.copyWith(color: gb.grey500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: AppDurations.base,
                    child: Icon(Icons.chevron_right, size: AppSizes.iconLg, color: gb.grey400),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Divider(height: 1, thickness: AppSizes.hairline, color: gb.borderCard),
            if (a.isBlind) const _BlindNote(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 1, AppSpacing.xs, AppSpacing.sm + 1, AppSpacing.sm + 1),
              child: _WorkoutPicker(planId: a.assignment.planId, assignmentId: a.assignment.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// Blind-plan note — workouts are not previewed; starting creates a session without a preview.
class _BlindNote extends StatelessWidget {
  const _BlindNote();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 1, AppSpacing.sm, AppSpacing.sm + 1, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: gb.grey0,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: gb.borderCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: AppSizes.iconMd, color: gb.grey500),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: Text(
                'Blind plan — workouts reveal only when you start; starting creates a session '
                'without a preview.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: gb.grey600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutPicker extends ConsumerWidget {
  const _WorkoutPicker({required this.planId, required this.assignmentId});
  final String planId;
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final detail = ref.watch(planDetailProvider(planId));
    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: GbSkeleton(height: 56, radius: AppRadius.sm),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          e is ApiException ? e.message : 'Could not load plan.',
          style: AppText.meta.copyWith(color: gb.grey500),
        ),
      ),
      data: (plan) {
        if (plan.workouts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text('This plan has no workouts.',
                style: AppText.meta.copyWith(color: gb.grey500)),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < plan.workouts.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _WorkoutRow(
                workout: plan.workouts[i],
                onStart: () => startFromAssignment(
                  context,
                  ref,
                  planAssignmentId: assignmentId,
                  plannedWorkoutId: plan.workouts[i].id,
                  replace: true,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A single workout (day) within an assignment — day order tile, name + exercise count, Start CTA.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout, required this.onStart});
  final PlanWorkoutDetail workout;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final count = workout.exercises.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: gb.grey0,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: gb.borderCard),
      ),
      child: Row(
        children: [
          GbIconTile(
            size: 36,
            radius: AppRadius.badge,
            background: gb.card,
            child: Text('${workout.order + 1}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: gb.grey700)
                    .tabular),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(workout.name, overflow: TextOverflow.ellipsis, style: AppText.rowTitle),
                const SizedBox(height: 1),
                Text(
                  count > 0 ? '$count exercise${count == 1 ? '' : 's'}' : 'Revealed at start',
                  style: AppText.meta.copyWith(color: gb.grey500),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GbButton(
            label: 'Start',
            icon: Icons.play_arrow,
            size: GbButtonSize.sm,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
