import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/plan_models.dart';
import '../../data/repositories/plan_repository.dart';
import '../tenant/tenant_controller.dart';

/// Active assigned plans for the trainee: assignment metadata joined with the plan's name/cadence
/// (the assignment list carries no name, so we merge `GET /workout-plans`). Watches active tenant.
final assignedPlansProvider = FutureProvider.autoDispose<List<AssignedPlan>>((ref) async {
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId == null) return const [];
  final repo = ref.read(planRepositoryProvider);
  final assignments = await repo.myAssignments(activeOnly: true);
  final plans = await repo.assignedPlans();
  final byId = {for (final p in plans.items) p.id: p};
  return [
    for (final a in assignments.items)
      AssignedPlan(
        assignment: a,
        planName: byId[a.planId]?.name,
        workoutsPerWeek: byId[a.planId]?.workoutsPerWeek,
      ),
  ];
});

/// A plan's full (server-redacted) detail. The server applies the assignment's visibility — render
/// as-is. Keyed by plan id.
final planDetailProvider =
    FutureProvider.autoDispose.family<WorkoutPlanDetail, String>((ref, planId) {
  ref.watch(activeTenantIdProvider);
  return ref.read(planRepositoryProvider).planDetail(planId);
});
