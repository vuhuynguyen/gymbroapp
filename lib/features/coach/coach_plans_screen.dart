import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/plan_models.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import '../auth/auth_controller.dart';
import 'coach_providers.dart';

/// Coach plan library — VIEW ONLY on mobile. Plan authoring (the immutable-versioned builder) stays
/// portal-first per the mobile strategy; here a coach reviews plans and assigns them to clients.
class CoachPlansScreen extends ConsumerWidget {
  const CoachPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(coachPlansProvider);

    return Scaffold(
      backgroundColor: context
          .gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
      body: Column(
        children: [
          GbAppHeader(
            title: 'Plans',
            actions: [
              GbBellButton(
                  onTap: () => showInfoSnack(context, 'No notifications yet'))
            ],
          ),
          Expanded(
            child: AsyncValueView(
              value: plans,
              onRetry: () async => ref.invalidate(coachPlansProvider),
              loading: const GbSkeletonList(count: 4, itemHeight: 110),
              data: (list) {
                if (list.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No plans yet',
                    subtitle:
                        'Create plans in the GymBro portal, then assign them here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(coachPlansProvider);
                    await ref.read(coachPlansProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                        AppSpacing.gap, AppSpacing.screenH, 90),
                    children: [
                      for (final p in list.items)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm - 2),
                          child: _PlanCard(plan: p),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Editing a plan saves an immutable new version. Build and edit plans in the '
                        'GymBro portal; existing assignments stay pinned to their version until you '
                        'apply the latest.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: context.gb.grey400),
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

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final WorkoutPlanSummary plan;

  /// Self-assign at Full visibility so the coach can run their own plan from the Log tab
  /// (BUSINESS_RULES "Train this myself").
  Future<void> _trainMyself(BuildContext context, WidgetRef ref) async {
    final me = ref.read(authControllerProvider).valueOrNull;
    if (me == null) return;
    try {
      await ref.read(planRepositoryProvider).createAssignment(
            traineeId: me.userId,
            planId: plan.id,
            startDate: DateTime.now(),
            frequencyDaysPerWeek: plan.workoutsPerWeek ?? 3,
            visibilityMode: PlanVisibilityMode.full,
          );
      ref.invalidate(coachClientsProvider);
      if (context.mounted) {
        showInfoSnack(
            context, 'Added to your workouts — start it from the Log tab.');
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showInfoSnack(
            context,
            e.isConflict
                ? 'This plan is already in your workouts.'
                : e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final meta = <(IconData, String)>[
      (Icons.layers_outlined, '${plan.workoutCount} workouts'),
      if (plan.workoutsPerWeek != null)
        (Icons.calendar_today_outlined, '${plan.workoutsPerWeek}×/wk'),
      if (plan.durationWeeks != null)
        (Icons.schedule, '${plan.durationWeeks} wks'),
    ];

    return Opacity(
      opacity: plan.isArchived ? 0.7 : 1,
      child: GbCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push('/plan-view/${plan.id}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(plan.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _VersionChip(label: 'v${plan.version}'),
                        if (plan.isArchived) ...[
                          const SizedBox(width: AppSpacing.xs - 2),
                          const _VersionChip(
                              label: 'Archived', icon: Icons.archive_outlined),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        for (final (icon, label) in meta)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon,
                                  size: AppSizes.iconSm, color: gb.grey500),
                              const SizedBox(width: 4),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 12.5, color: gb.grey500)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!plan.isArchived)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gap, 0, AppSpacing.gap, AppSpacing.sm),
                child: Row(
                  children: [
                    GbButton(
                      label: 'Train this myself',
                      icon: Icons.fitness_center,
                      size: GbButtonSize.sm,
                      variant: GbButtonVariant.text,
                      onPressed: () => _trainMyself(context, ref),
                    ),
                    const Spacer(),
                    GbButton(
                      label: 'Assign',
                      icon: Icons.person_add_alt,
                      size: GbButtonSize.sm,
                      variant: GbButtonVariant.outlined,
                      severity: GbButtonSeverity.secondary,
                      onPressed: () => context.push('/assign/${plan.id}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small grey version / archived chip (design plan-card tag).
class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: gb.grey25, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: gb.grey600),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gb.grey600)),
        ],
      ),
    );
  }
}
