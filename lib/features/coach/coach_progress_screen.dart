import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/coach_models.dart';
import '../../shared/widgets/widgets.dart';
import 'coach_providers.dart';
import 'coach_widgets.dart';

/// The coach Progress roster (Phase 2b) — an at-risk-first triage list answering the one question a
/// busy coach opens this view for: *which client do I message today?* Tenant-scoped (own gym only);
/// the roster leads with the verdict, sorted Quiet → Drifting → On track (management by exception).
/// See gymbro/docs/progress/COACH-VS-TRAINEE.md §2.
///
/// Each row: a status chip (Quiet = amber/danger, Drifting = warning, On track = success), an
/// adherence mini-ring (`done/goal`) or a raw count when there's no plan goal, and a last-active
/// relative label. The mandatory "this gym only" caption frames the scope — a client who trains
/// across two gyms can legitimately read Quiet here.
///
/// Reachable as a full-screen route off the Coach hub (`/coach-progress`). Tapping a client opens the
/// per-client detail. Renders skeleton / ErrorRetry / "No clients yet" / data.
class CoachProgressScreen extends ConsumerWidget {
  const CoachProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(coachRosterProvider);

    return Scaffold(
      backgroundColor: context.gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
      body: Column(
        children: [
          GbDetailHeader(
            title: 'Client progress',
            onLeading: () => context.canPop() ? context.pop() : context.go('/coach'),
          ),
          Expanded(
            child: AsyncValueView(
              value: roster,
              onRetry: () async => ref.invalidate(coachRosterProvider),
              loading: const GbSkeletonList(count: 5),
              data: (r) {
                if (r.isEmpty) {
                  return const EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'No clients yet',
                    subtitle: 'Invite a client with a code to start tracking their progress.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(coachRosterProvider);
                    await ref.read(coachRosterProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, 90),
                    children: [
                      const _ScopeCaption(),
                      const SizedBox(height: AppSpacing.gap),
                      for (final c in r.triaged)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _RosterRow(client: c),
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

/// The mandatory "this gym only" scope caption (COACH-VS-TRAINEE.md §2). Prevents the coach from
/// misreading cross-gym silence as inactivity — a client who trains elsewhere reads Quiet here, which
/// is correct: this gym genuinely saw no sessions.
class _ScopeCaption extends StatelessWidget {
  const _ScopeCaption();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      children: [
        Icon(Icons.place_outlined, size: AppSizes.iconSm, color: gb.grey400),
        const SizedBox(width: AppSpacing.xs - 2),
        Text('This gym only', style: AppText.meta.copyWith(color: gb.grey500)),
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.client});
  final ClientStatus client;

  @override
  Widget build(BuildContext context) {
    return GbTappableRow(
      onTap: () => context.push(
          '/coach-client/${client.traineeId}?name=${Uri.encodeComponent(client.displayName)}'),
      leading: Avatar(initial: client.initial, size: 44),
      title: client.displayName,
      subtitle: _lastActiveLabel(client.lastActiveAt),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RosterStatusBadge(status: client.status),
          const SizedBox(width: AppSpacing.xs),
          _AdherenceCue(client: client),
        ],
      ),
    );
  }
}

/// The adherence cue on a roster row: a mini-ring with `done/goal` when there's a plan goal, else a
/// quiet raw "N done" count (no fabricated denominator when the client has no active plan in this gym).
class _AdherenceCue extends StatelessWidget {
  const _AdherenceCue({required this.client});
  final ClientStatus client;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    if (!client.hasGoal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${client.completedThisWeek}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: gb.grey700)
                  .tabular),
          Text('done', style: AppText.meta.copyWith(color: gb.grey400)),
        ],
      );
    }
    return GbRing(
      value: client.ringValue,
      size: 40,
      stroke: 4,
      gradient: const [AppPalette.primary200, AppPalette.primary700],
      child: Text('${client.completedThisWeek}/${client.weeklyGoal}',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: gb.grey900)
              .tabular),
    );
  }
}

/// "Trained today / yesterday / Nd ago / Nw ago" — the leading churn signal. "No sessions yet" when
/// the client has never trained in this gym (the most-stale state, sorted to the top of the roster).
String _lastActiveLabel(DateTime? at) {
  if (at == null) return 'No sessions yet';
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
  if (days <= 0) return 'Trained today';
  if (days == 1) return 'Trained yesterday';
  if (days < 7) return 'Trained ${days}d ago';
  final weeks = days ~/ 7;
  return 'Trained ${weeks}w ago';
}
