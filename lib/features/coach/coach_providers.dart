import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/coach_models.dart';
import '../../data/models/plan_models.dart';
import '../../data/models/tenant_models.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/tenant_repository.dart';
import '../tenant/tenant_controller.dart';

/// Resolve plan names for a set of (version-pinned) plan ids. Can't use the plans list — assignments
/// pin a *specific version*, which may not be the latest in the list — so fetch each by id.
Future<Map<String, String>> _planNames(PlanRepository repo, Iterable<String> planIds) async {
  final ids = planIds.toSet();
  final entries = await Future.wait(ids.map((id) async {
    try {
      final d = await repo.planDetail(id);
      return MapEntry(id, d.name);
    } catch (_) {
      return MapEntry(id, '');
    }
  }));
  return {for (final e in entries) if (e.value.isNotEmpty) e.key: e.value};
}

/// Coach roster — Clients joined with their active assignment (plan + visibility + frequency).
final coachClientsProvider = FutureProvider.autoDispose<List<ClientSummary>>((ref) async {
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId == null) return const [];

  final members = await ref.read(tenantRepositoryProvider).members(tenantId);
  final clients = members.where((m) => m.isClient).toList();

  final planRepo = ref.read(planRepositoryProvider);
  final assignments = await planRepo.allAssignments();

  final activeByTrainee = <String, PlanAssignmentSummary>{};
  for (final a in assignments.items) {
    if (a.isActive) activeByTrainee.putIfAbsent(a.traineeId, () => a);
  }
  final names = await _planNames(planRepo, activeByTrainee.values.map((a) => a.planId));

  return [
    for (final c in clients)
      ClientSummary(
        userId: c.userId,
        name: c.name,
        activeAssignmentId: activeByTrainee[c.userId]?.id,
        planName: activeByTrainee[c.userId] == null ? null : names[activeByTrainee[c.userId]!.planId],
        visibility: activeByTrainee[c.userId]?.visibilityMode,
        frequency: activeByTrainee[c.userId]?.frequencyDaysPerWeek,
      ),
  ];
});

/// Coach plan library (view). Owner sees the latest version per template.
final coachPlansProvider = FutureProvider.autoDispose<WorkoutPlanList>((ref) {
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId == null) {
    return Future.value(const WorkoutPlanList(items: [], page: 1, pageSize: 200, totalCount: 0));
  }
  return ref.read(planRepositoryProvider).listPlans();
});

/// Active invite codes for the workspace (Owner-only).
final coachInvitesProvider = FutureProvider.autoDispose<List<InviteCode>>((ref) {
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId == null) return Future.value(const <InviteCode>[]);
  return ref.read(tenantRepositoryProvider).invites();
});

/// One client's assignments (with resolved plan names) + recent sessions.
final clientMonitorProvider =
    FutureProvider.autoDispose.family<ClientMonitorData, String>((ref, clientId) async {
  ref.watch(activeTenantIdProvider);
  final planRepo = ref.read(planRepositoryProvider);

  final assignmentList = await planRepo.assignmentsForTrainee(clientId);
  final names = await _planNames(planRepo, assignmentList.items.map((a) => a.planId));
  final assignments = [
    for (final a in assignmentList.items) AssignedPlan(assignment: a, planName: names[a.planId]),
  ];

  final sessions = await ref.read(sessionRepositoryProvider).list(traineeId: clientId, pageSize: 20);
  return ClientMonitorData(assignments: assignments, sessions: sessions.items);
});
