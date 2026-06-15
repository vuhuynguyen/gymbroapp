import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/coach_models.dart';
import '../../data/models/plan_models.dart';
import '../../data/models/progress_models.dart';
import '../../data/models/tenant_models.dart';
import '../../data/repositories/coach_progress_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/tenant_repository.dart';
import '../../shared/paging/paged.dart';
import '../tenant/tenant_controller.dart';

/// Resolve plan names for a set of (version-pinned) plan ids. Can't use the plans list — assignments
/// pin a *specific version*, which may not be the latest in the list — so fetch each by id.
Future<Map<String, String>> _planNames(
    PlanRepository repo, Iterable<String> planIds) async {
  final ids = planIds.toSet();
  final entries = await Future.wait(ids.map((id) async {
    try {
      final d = await repo.planDetail(id);
      return MapEntry(id, d.name);
    } catch (_) {
      return MapEntry(id, '');
    }
  }));
  return {
    for (final e in entries)
      if (e.value.isNotEmpty) e.key: e.value
  };
}

/// Coach roster — Clients joined with their active assignment (plan + visibility + frequency).
final coachClientsProvider =
    FutureProvider.autoDispose<List<ClientSummary>>((ref) async {
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
  final names =
      await _planNames(planRepo, activeByTrainee.values.map((a) => a.planId));

  return [
    for (final c in clients)
      ClientSummary(
        userId: c.userId,
        name: c.name,
        activeAssignmentId: activeByTrainee[c.userId]?.id,
        planName: activeByTrainee[c.userId] == null
            ? null
            : names[activeByTrainee[c.userId]!.planId],
        visibility: activeByTrainee[c.userId]?.visibilityMode,
        frequency: activeByTrainee[c.userId]?.frequencyDaysPerWeek,
      ),
  ];
});

/// Coach plan library (view), paged with infinite scroll. Owner sees the latest version per template.
class CoachPlansNotifier extends PagedNotifier<WorkoutPlanSummary> {
  @override
  int get pageSize => 20;

  @override
  AsyncValue<PagedData<WorkoutPlanSummary>> build() {
    ref.watch(
        activeTenantIdProvider); // reload page 1 when the active gym changes
    return super.build();
  }

  @override
  Future<PageResult<WorkoutPlanSummary>> fetch(int page, int pageSize) async {
    if (ref.read(activeTenantIdProvider) == null) {
      return const PageResult([], 0);
    }
    final r = await ref
        .read(planRepositoryProvider)
        .listPlans(page: page, pageSize: pageSize);
    return PageResult(r.items, r.totalCount);
  }
}

final coachPlansProvider = AutoDisposeNotifierProvider<CoachPlansNotifier,
    AsyncValue<PagedData<WorkoutPlanSummary>>>(CoachPlansNotifier.new);

/// Active invite codes for the workspace (Owner-only).
final coachInvitesProvider =
    FutureProvider.autoDispose<List<InviteCode>>((ref) {
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId == null) return Future.value(const <InviteCode>[]);
  return ref.read(tenantRepositoryProvider).invites();
});

/// One client's assignments (with resolved plan names) + recent sessions.
final clientMonitorProvider = FutureProvider.autoDispose
    .family<ClientMonitorData, String>((ref, clientId) async {
  ref.watch(activeTenantIdProvider);
  final planRepo = ref.read(planRepositoryProvider);

  final assignmentList = await planRepo.assignmentsForTrainee(clientId);
  final names =
      await _planNames(planRepo, assignmentList.items.map((a) => a.planId));
  final assignments = [
    for (final a in assignmentList.items)
      AssignedPlan(assignment: a, planName: names[a.planId]),
  ];

  final sessions = await ref
      .read(sessionRepositoryProvider)
      .list(traineeId: clientId, pageSize: 20);
  return ClientMonitorData(assignments: assignments, sessions: sessions.items);
});

// ── Coach Progress surface (Phase 2b) — tenant-scoped, own gym only ──
// Both providers watch [activeTenantIdProvider] so they refetch (and reset) on a workspace switch —
// the coach's roster and any per-client trend are gym-specific. They return empty when there's no
// active tenant rather than firing a tenant-less read (which would be ambiguous / leak-prone).

/// The coach roster — an at-risk-first triage list of the active gym's clients
/// (`GET /api/clients/progress/roster`). Tenant-scoped (the `AuthInterceptor` sends `X-Tenant-Id`).
final coachRosterProvider = FutureProvider.autoDispose<Roster>((ref) async {
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId == null) return const Roster(items: []);
  return ref.read(coachProgressRepositoryProvider).roster();
});

/// One client's per-lift strength trend, built from TENANT-SCOPED sessions (own gym)
/// (`GET /api/clients/{traineeId}/progress/strength`). Keyed by `traineeId`; watches
/// [activeTenantIdProvider] so it refetches on a gym switch. The server 403/404s a non-member id.
final clientStrengthProvider = FutureProvider.autoDispose
    .family<List<ExerciseE1rmSeries>, String>((ref, traineeId) async {
  ref.watch(activeTenantIdProvider);
  return ref.read(coachProgressRepositoryProvider).clientStrength(traineeId);
});

/// One client's acute-vs-chronic workload, built from TENANT-SCOPED sessions (own gym)
/// (`GET /api/clients/{traineeId}/progress/load`, Phase 4 / Decision D14). Keyed by `traineeId`;
/// watches [activeTenantIdProvider] so it refetches on a gym switch. Loads independently of
/// [clientStrengthProvider] so the workload card never blocks the strength trends above it — the
/// server 403/404s a non-member id (surfaced as a real error, never masked / rescoped to self).
final clientLoadProvider = FutureProvider.autoDispose
    .family<AcuteChronicLoad, String>((ref, traineeId) async {
  ref.watch(activeTenantIdProvider);
  return ref.read(coachProgressRepositoryProvider).clientLoad(traineeId);
});
