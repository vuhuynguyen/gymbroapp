import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/app_time_zone.dart';
import '../../core/time/relative_day.dart';
import '../../data/models/coach_models.dart';
import '../../data/models/plan_models.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session_grouping.dart';
import '../../domain/session_metrics.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/client_nutrition_panel.dart';
import 'client_progress_panel.dart';
import 'coach_providers.dart';

/// Read + light-mutation monitoring of one client: adherence, the version-pinned assignment
/// (pause/resume, apply-latest), and recent sessions. Authorization is server-side (WorkoutLogViewAll).
class ClientMonitorScreen extends ConsumerWidget {
  const ClientMonitorScreen(
      {required this.clientId, this.clientName, super.key});
  final String clientId;
  final String? clientName;

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(clientMonitorProvider(clientId));
      ref.invalidate(coachClientsProvider);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(clientMonitorProvider(clientId));
    return Scaffold(
      backgroundColor: context
          .gb.grey0, // coach screens use the design's warmer grey-0 (#f7f8f9)
      body: Column(
        children: [
          GbDetailHeader(title: 'Client', onLeading: () => context.pop()),
          Expanded(
            child: AsyncValueView(
              value: data,
              onRetry: () async =>
                  ref.invalidate(clientMonitorProvider(clientId)),
              data: (d) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clientMonitorProvider(clientId));
                  await ref.read(clientMonitorProvider(clientId).future);
                },
                child: _Body(
                  clientId: clientId,
                  clientName: clientName,
                  data: d,
                  onPauseResume: (a) => _run(
                      context,
                      ref,
                      () => ref
                          .read(planRepositoryProvider)
                          .setAssignmentActive(
                              a.assignment.id, !a.assignment.isActive)),
                  onApplyLatest: (a) => _run(
                      context,
                      ref,
                      () => ref
                          .read(planRepositoryProvider)
                          .applyLatest(a.assignment.id)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.clientId,
    required this.clientName,
    required this.data,
    required this.onPauseResume,
    required this.onApplyLatest,
  });

  final String clientId;
  final String? clientName;
  final ClientMonitorData data;
  final ValueChanged<AssignedPlan> onPauseResume;
  final ValueChanged<AssignedPlan> onApplyLatest;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final name = clientName ?? 'Client';
    final initial = (clientName != null && clientName!.isNotEmpty)
        ? clientName![0].toUpperCase()
        : '?';

    final completed = data.sessions
        .where((s) => s.status == SessionStatus.completed)
        .toList();
    // Count this week's completed sessions in each session's own captured zone (the trainee's local week).
    final doneThisWeek = completed.where((s) {
      if (s.startedAt == null) return false;
      final local = AppTimeZone.wallClock(s.startedAt!, s.clientTimezone);
      final monday =
          mondayOf(AppTimeZone.wallClock(DateTime.now(), s.clientTimezone));
      return !local.isBefore(monday);
    }).length;
    final active =
        data.assignments.where((a) => a.assignment.isActive).toList();
    final goal =
        active.isNotEmpty ? active.first.assignment.frequencyDaysPerWeek : 0;
    final volume = completed.fold<double>(0, (a, s) => a + s.totalVolumeKg);
    final prs = completed.fold<int>(0, (a, s) => a + s.prCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.lg),
      children: [
        // Identity — avatar, name, "Client · N sessions logged", adherence ring.
        Row(
          children: [
            Avatar(initial: initial, size: 56, ring: true),
            const SizedBox(width: AppSpacing.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: gb.ink)),
                  const SizedBox(height: 3),
                  Text('Client · ${completed.length} sessions logged',
                      style: TextStyle(fontSize: 12, color: gb.grey500)),
                ],
              ),
            ),
            GbRing(
              value: goal > 0 ? doneThisWeek / goal : 0,
              size: 48,
              stroke: 5,
              gradient: const [AppPalette.primary200, AppPalette.primary700],
              child: Text('$doneThisWeek/${goal > 0 ? goal : 0}',
                  style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: gb.grey900)
                      .tabular),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Stat tiles.
        Row(
          children: [
            Expanded(
                child: GbStatTile(
                    icon: Icons.history,
                    value: '$doneThisWeek',
                    label: 'This wk')),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
                child: GbStatTile(
                    icon: Icons.bar_chart,
                    value: _fmtVolume(volume),
                    unit: 'kg',
                    label: 'Volume',
                    accent: gb.primary500)),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
                child: GbStatTile(
                    icon: Icons.emoji_events,
                    value: '$prs',
                    label: 'PRs',
                    accent: gb.amber)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Assignment card(s).
        if (data.assignments.isEmpty)
          _NoPlanCard(
              firstName: name.split(' ').first,
              onAssign: () => _assign(context))
        else
          for (final a in data.assignments)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AssignmentCard(
                assignment: a,
                onPauseResume: () => onPauseResume(a),
                onApplyLatest: () => onApplyLatest(a),
                onReassign: () => _assign(context),
              ),
            ),
        if (data.assignments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          GbButton(
            label: 'Assign another plan',
            icon: Icons.add,
            variant: GbButtonVariant.outlined,
            severity: GbButtonSeverity.secondary,
            full: true,
            onPressed: () => _assign(context),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        // Workouts · Nutrition · Progress.
        _ClientTabs(
            clientId: clientId, clientName: name, sessions: data.sessions),
      ],
    );
  }

  void _assign(BuildContext context) {
    // The coach picks the plan first on the Coach hub's Plans segment; from here jump there.
    context.go('/coach');
  }
}

enum _ClientSegment { workouts, nutrition, progress }

/// The three monitoring lenses on a client — their workout sessions, nutrition adherence, and
/// progress trends. The fixed identity / assignment header sits above this in the monitor list.
class _ClientTabs extends StatefulWidget {
  const _ClientTabs(
      {required this.clientId,
      required this.clientName,
      required this.sessions});
  final String clientId;
  final String clientName;
  final List<SessionSummary> sessions;

  @override
  State<_ClientTabs> createState() => _ClientTabsState();
}

class _ClientTabsState extends State<_ClientTabs> {
  _ClientSegment _seg = _ClientSegment.workouts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GbSegmented<_ClientSegment>(
          value: _seg,
          options: const [
            (_ClientSegment.workouts, 'Workouts'),
            (_ClientSegment.nutrition, 'Nutrition'),
            (_ClientSegment.progress, 'Progress'),
          ],
          onChanged: (s) => setState(() => _seg = s),
        ),
        const SizedBox(height: AppSpacing.gap),
        switch (_seg) {
          _ClientSegment.workouts => _WorkoutsList(sessions: widget.sessions),
          _ClientSegment.nutrition => ClientNutritionPanel(
              clientId: widget.clientId, clientName: widget.clientName),
          _ClientSegment.progress =>
            ClientProgressPanel(sessions: widget.sessions),
        },
      ],
    );
  }
}

/// The Workouts segment — recent sessions (the original monitor list).
class _WorkoutsList extends StatelessWidget {
  const _WorkoutsList({required this.sessions});
  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GbSectionTitle('Recent sessions'),
        const SizedBox(height: AppSpacing.sm),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text('No sessions logged yet.',
                  style: TextStyle(fontSize: 13, color: gb.grey400)),
            ),
          )
        else
          for (final s in sessions)
            GbSessionRow(
              day: _weekdayAbbr(s.startedAt, s.clientTimezone),
              status: s.status,
              title: s.workoutName ?? s.programName ?? 'Session',
              source: s.source,
              relativeTime: relativeDayLabel(s.startedAt, s.clientTimezone),
              durationLabel: s.durationSeconds != null
                  ? formatDurationCompact(s.durationSeconds!)
                  : null,
              volumeLabel: s.totalVolumeKg > 0
                  ? '${_fmtVolume(s.totalVolumeKg)} kg'
                  : null,
              prCount: s.prCount,
              rpe: s.rpeOverall,
              onTap: () => context.push('/session-detail/${s.id}'),
            ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onPauseResume,
    required this.onApplyLatest,
    required this.onReassign,
  });
  final AssignedPlan assignment;
  final VoidCallback onPauseResume;
  final VoidCallback onApplyLatest;
  final VoidCallback onReassign;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final a = assignment.assignment;
    final meta = <String>[
      'Pinned v${a.planVersion}',
      '${a.frequencyDaysPerWeek}×/week',
      if (a.startDate != null) 'Started ${_shortDate(a.startDate!)}',
    ];

    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child:
                      Text('Current assignment', style: AppText.sectionTitle)),
              if (!a.isActive) ...[
                GbStatusBadge(
                    label: 'Paused',
                    background: gb.warning0,
                    foreground: gb.warning300,
                    stadium: false),
                const SizedBox(width: AppSpacing.xs - 2),
              ],
              VisBadge(a.visibilityMode),
            ],
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Text(assignment.planName ?? 'Assigned plan',
              style: AppText.rowTitle.copyWith(color: gb.grey900)),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 2,
            children: [
              for (final m in meta)
                Text(m, style: TextStyle(fontSize: 12, color: gb.grey500)),
            ],
          ),
          if (a.hasNewerVersion) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: gb.secondary0,
                borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                border: Border.all(color: gb.primary25),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh,
                      size: AppSizes.iconMd, color: gb.primary600),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Newer version '),
                        TextSpan(
                            text: 'v${a.latestPlanVersion}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const TextSpan(text: ' available'),
                      ]),
                      style: TextStyle(fontSize: 12, color: gb.grey700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GbButton(
                    label: 'Apply latest',
                    size: GbButtonSize.sm,
                    onPressed: onApplyLatest,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: GbButton(
                  label: a.isActive ? 'Pause' : 'Resume',
                  icon: a.isActive ? Icons.pause : Icons.play_arrow,
                  size: GbButtonSize.sm,
                  variant: GbButtonVariant.outlined,
                  severity: GbButtonSeverity.secondary,
                  full: true,
                  onPressed: onPauseResume,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: GbButton(
                  label: 'Reassign',
                  icon: Icons.edit_outlined,
                  size: GbButtonSize.sm,
                  variant: GbButtonVariant.outlined,
                  severity: GbButtonSeverity.secondary,
                  full: true,
                  onPressed: onReassign,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashed "no active plan" call-out with an Assign CTA (design unassigned state).
class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.firstName, required this.onAssign});
  final String firstName;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      dashed: true,
      padding: const EdgeInsets.all(AppSpacing.heroPad),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: AppSizes.iconXxl + 2, color: gb.grey400),
          const SizedBox(height: AppSpacing.xs),
          Text('No active plan',
              style: AppText.rowTitle.copyWith(color: gb.grey700)),
          const SizedBox(height: AppSpacing.xxs),
          Text('Assign a plan to start coaching $firstName.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: gb.grey400)),
          const SizedBox(height: AppSpacing.sm),
          GbButton(
              label: 'Assign a plan', icon: Icons.add, onPressed: onAssign),
        ],
      ),
    );
  }
}

String _fmtVolume(double kg) =>
    kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)}k' : kg.toStringAsFixed(0);

String _weekdayAbbr(DateTime? d, [String? zone]) {
  if (d == null) return '—';
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[(AppTimeZone.wallClock(d, zone).weekday - 1).clamp(0, 6)];
}

String _shortDate(DateTime d) {
  const months = [
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
  final local = d.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}
