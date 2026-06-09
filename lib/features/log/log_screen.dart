import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/session_models.dart';
import '../../domain/enums.dart';
import '../../domain/session_grouping.dart';
import '../../domain/session_metrics.dart';
import '../../shared/widgets/widgets.dart';
import '../plan/plan_providers.dart';
import '../session/start_actions.dart';
import 'log_providers.dart';

/// The Workout Log — home. Session-first timeline: app header, active-session hero (resume),
/// this-week goal ring, status filter chips, and collapsible Monday-anchored week groups. "Start
/// Workout" is the bottom-nav centre button → [showStartWorkoutSheet]. Volume in kg, the stored unit.
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  SessionStatus? _filter; // null = All

  Future<void> _refresh() async {
    ref.invalidate(activeSessionProvider);
    ref.invalidate(sessionHistoryProvider);
    await ref.read(sessionHistoryProvider.future);
  }

  bool _matches(SessionSummary s) => _filter == null || s.status == _filter;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider).valueOrNull;
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      body: Column(
        children: [
          _LogHeader(history: history.valueOrNull?.items),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: history.when(
                loading: () => ListView(children: [
                  if (active != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                          AppSpacing.gap, AppSpacing.screenH, 0),
                      child: _Hero(session: active),
                    ),
                  const GbSkeletonList(count: 5),
                ]),
                error: (e, _) => ListView(children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: ErrorRetry(
                      message:
                          "We couldn't load your workout history. Pull to refresh or try again.",
                      onRetry: () async =>
                          ref.invalidate(sessionHistoryProvider),
                    ),
                  ),
                ]),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.gap, AppSpacing.screenH, 100),
                  children: [
                    if (active != null) ...[
                      _Hero(session: active),
                      const SizedBox(height: AppSpacing.gap)
                    ],
                    _History(
                      list: list,
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                      matches: _matches,
                      onOpen: (s) {
                        if (s.status == SessionStatus.inProgress) {
                          context.push('/session/${s.id}');
                        } else {
                          context.push('/session-detail/${s.id}?me=1');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayAbbr(DateTime? d) {
  if (d == null) return '—';
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[(d.toLocal().weekday - 1).clamp(0, 6)];
}

String _fmtVolume(double kg) =>
    kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)}k' : kg.toStringAsFixed(0);

/// Relative day label for a session row: Today / Yesterday / weekday / d/m.
String _relativeTime(DateTime? d) {
  if (d == null) return '';
  final local = d.toLocal();
  final today = DateTime.now();
  final dayOnly = DateTime(local.year, local.month, local.day);
  final todayOnly = DateTime(today.year, today.month, today.day);
  final diff = todayOnly.difference(dayOnly).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) {
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ][local.weekday - 1];
  }
  return '${local.day}/${local.month}';
}

/// Consecutive-day streak: calendar days (ending today/yesterday) with ≥1 completed session.
/// A genuine client-derived metric (like Progress); returns 0 when the chain is broken — never faked.
int _dayStreak(List<SessionSummary>? sessions) {
  if (sessions == null || sessions.isEmpty) return 0;
  final days = <DateTime>{};
  for (final s in sessions) {
    if (s.status != SessionStatus.completed) continue;
    final d = (s.completedAt ?? s.startedAt)?.toLocal();
    if (d != null) days.add(DateTime(d.year, d.month, d.day));
  }
  if (days.isEmpty) return 0;
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0; // last activity older than yesterday
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

class _Hero extends StatefulWidget {
  const _Hero({required this.session});
  final ActiveSession session;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.session.status.isInProgress) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final gb = context.gb;
    final logged = countLoggedSets(session.exercises);
    final planned =
        session.snapshot?.exercises.fold<int>(0, (a, e) => a + e.sets.length) ??
            0;
    final total = planned > logged ? planned : logged;
    final pct = computeProgressPercent(logged, total);
    // Ad-hoc sessions have no planned target, so "of N sets" / "100%" / a full progress bar are
    // meaningless (logged always == total). Only plan sessions show progress.
    final hasTarget = session.source != SessionSource.adhoc && planned > 0;
    final name = session.snapshot?.workoutName ?? 'Ad-hoc workout';
    final elapsed = session.startedAt == null
        ? null
        : formatDuration(computeElapsedSeconds(
            session.startedAt!.millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
            0));

    return GbHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulsingDot(color: AppPalette.liveDot),
              const SizedBox(width: AppSpacing.xs),
              const Eyebrow('Live session', color: AppPalette.primary50),
              const Spacer(),
              if (elapsed != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(elapsed,
                          style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5)
                              .tabular),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(name, style: AppText.heroTitle.copyWith(color: Colors.white)),
          // Only plan-sourced sessions carry program context; never label an ad-hoc session "Plan".
          if (session.source != SessionSource.adhoc) ...[
            const SizedBox(height: 2),
            Text('Plan workout',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72), fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.md),
          // Plan: progress toward the planned target. Ad-hoc: just the running set count.
          if (hasTarget) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$logged',
                      style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)
                          .tabular),
                  TextSpan(
                      text: ' of $total sets',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ])),
                Text('$pct%',
                    style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)
                        .tabular),
              ],
            ),
            const SizedBox(height: 6),
            _ProgressBar(
                value: total > 0 ? (logged / total).clamp(0.0, 1.0) : 0),
          ] else
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '$logged',
                  style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)
                      .tabular),
              TextSpan(
                  text: ' ${logged == 1 ? 'set' : 'sets'} logged',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(height: AppSpacing.md),
          _OnHeroButton(
            label: 'Resume workout',
            icon: Icons.play_arrow,
            color: gb.primary700,
            onTap: () => context.push('/session/${session.sessionId}'),
          ),
        ],
      ),
    );
  }
}

/// White-filled CTA that sits ON the gradient hero (design Resume button): white bg, primary-ink
/// label, full width, soft drop shadow.
class _OnHeroButton extends StatelessWidget {
  const _OnHeroButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // White fill lives in the DecoratedBox (a raw Material(color:) renders grey in this app — same
    // reason GbSessionRow moved to GbCard); a transparent Material on top just carries the ripple.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.brSm,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              spreadRadius: -6,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: AppSizes.iconLg, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 9,
          width: double.infinity,
          child: Stack(
            children: [
              const ColoredBox(color: Colors.white24),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: GbColors.progressFill)),
              ),
            ],
          ),
        ),
      );
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The live-dot pulse is the one infinite loop the design allows — but it still honors reduced
    // motion (design Motion §): hold the solid dot with no expanding ring.
    if (context.reduceMotion) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Container(
              width: 7 + _c.value * 7,
              height: 7 + _c.value * 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        widget.color.withValues(alpha: (1 - _c.value) * 0.5)),
              ),
            ),
          ),
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({
    required this.list,
    required this.filter,
    required this.onFilter,
    required this.matches,
    required this.onOpen,
  });

  final SessionList list;
  final SessionStatus? filter;
  final ValueChanged<SessionStatus?> onFilter;
  final bool Function(SessionSummary) matches;
  final ValueChanged<SessionSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = list.items;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: EmptyState(
          icon: Icons.fitness_center,
          title: 'No sessions yet',
          subtitle: 'Tap Start Workout to log your first session.',
        ),
      );
    }

    final weeks = groupSessionsByWeek(items);
    final now = DateTime.now();
    final thisWeek = weeks.where((w) => w.label(now) == 'This week').toList();

    final counts = <SessionStatus?, int>{
      null: items.length,
      SessionStatus.completed:
          items.where((s) => s.status == SessionStatus.completed).length,
      SessionStatus.inProgress:
          items.where((s) => s.status == SessionStatus.inProgress).length,
      SessionStatus.abandoned:
          items.where((s) => s.status == SessionStatus.abandoned).length,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (thisWeek.isNotEmpty) _WeekSummaryCard(week: thisWeek.first),
        const SizedBox(height: AppSpacing.gap),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(context, 'All', null, counts[null]!, Icons.layers_outlined),
              _chip(context, 'Completed', SessionStatus.completed,
                  counts[SessionStatus.completed]!, Icons.check),
              _chip(context, 'In progress', SessionStatus.inProgress,
                  counts[SessionStatus.inProgress]!, Icons.play_arrow),
              _chip(context, 'Abandoned', SessionStatus.abandoned,
                  counts[SessionStatus.abandoned]!, Icons.flag_outlined),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        for (var wi = 0; wi < weeks.length; wi++)
          _WeekGroup(
              week: weeks[wi],
              now: now,
              matches: matches,
              onOpen: onOpen,
              initiallyExpanded: wi == 0),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, SessionStatus? value,
          int count, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: GbChip(
          label: label,
          icon: icon,
          count: count,
          selected: filter == value,
          selectedColor: context.gb.grey900,
          onTap: () => onFilter(value),
        ),
      );
}

class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard({required this.week});
  final SessionWeek week;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final goal = week.weeklyGoal;
    final sets = week.sessions.fold<int>(0, (a, s) => a + s.totalSets);
    final left = goal != null ? (goal - week.completedCount).clamp(0, goal) : 0;
    return GbCard(
      padding: const EdgeInsets.all(AppSpacing.heroPad),
      child: Row(
        children: [
          GbRing(
            value: goal != null && goal > 0 ? week.completedCount / goal : 0,
            size: 70,
            stroke: 8,
            gradient: const [AppPalette.primary200, AppPalette.primary700],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${week.completedCount}',
                    style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1)
                        .tabular),
                if (goal != null)
                  Text('of $goal',
                      style: TextStyle(
                              fontSize: 10,
                              color: gb.grey400,
                              fontWeight: FontWeight.w700)
                          .tabular),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.heroPad),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('This week'),
                const SizedBox(height: 3),
                Text(
                  goal != null
                      ? (left > 0
                          ? '$left session${left == 1 ? '' : 's'} to your goal'
                          : 'Goal reached')
                      : 'Keep logging your sessions',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: gb.ink,
                      letterSpacing: -0.15),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _kpi(context, _fmtVolume(week.volumeKg), 'kg', 'Volume'),
                    const SizedBox(width: 22),
                    _kpi(context, '$sets', null, 'Sets'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String value, String? unit, String label) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: gb.ink)
                    .tabular),
            if (unit != null)
              Text(' $unit',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: gb.grey400)),
          ],
        ),
        const SizedBox(height: 1),
        Eyebrow(label),
      ],
    );
  }
}

/// Collapsible Monday-anchored week group (design: rotating chevron, per-week ring + PR chip).
class _WeekGroup extends StatefulWidget {
  const _WeekGroup(
      {required this.week,
      required this.now,
      required this.matches,
      required this.onOpen,
      required this.initiallyExpanded});
  final SessionWeek week;
  final DateTime now;
  final bool Function(SessionSummary) matches;
  final ValueChanged<SessionSummary> onOpen;
  final bool initiallyExpanded;

  @override
  State<_WeekGroup> createState() => _WeekGroupState();
}

class _WeekGroupState extends State<_WeekGroup> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final week = widget.week;
    final visible = week.sessions.where(widget.matches).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final goal = week.weeklyGoal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, AppSpacing.sm - 2),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: AppDurations.base,
                  child: Icon(Icons.chevron_right,
                      size: AppSizes.iconMd, color: gb.grey400),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(week.label(widget.now),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: gb.ink,
                        letterSpacing: -0.14)),
                if (week.programLabel != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(week.programLabel!,
                        style: AppText.meta.copyWith(color: gb.grey400),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
                const Spacer(),
                if (week.prCount > 0) ...[
                  const PrChip(small: true),
                  const SizedBox(width: AppSpacing.xs)
                ],
                if (goal != null) ...[
                  GbRing(
                      value: goal > 0 ? week.completedCount / goal : 0,
                      size: 24,
                      stroke: 3.5,
                      gradient: const [
                        AppPalette.primary200,
                        AppPalette.primary700
                      ]),
                  const SizedBox(width: 6),
                  Text('${week.completedCount}/$goal',
                      style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: gb.grey600)
                          .tabular),
                ],
              ],
            ),
          ),
        ),
        if (_open)
          for (final s in visible)
            GbSessionRow(
              day: _weekdayAbbr(s.startedAt),
              status: s.status,
              title: s.workoutName ?? s.programName ?? 'Session',
              source: s.source,
              relativeTime: _relativeTime(s.startedAt),
              durationLabel: s.durationSeconds != null
                  ? formatDurationCompact(s.durationSeconds!)
                  : null,
              volumeLabel: s.totalVolumeKg > 0
                  ? '${_fmtVolume(s.totalVolumeKg)} kg'
                  : null,
              prCount: s.prCount,
              rpe: s.rpeOverall,
              onTap: () => widget.onOpen(s),
            ),
      ],
    );
  }
}

/// Log header — ring avatar + time-aware greeting + name + streak chip + notification bell.
class _LogHeader extends StatelessWidget {
  const _LogHeader({this.history});
  final List<SessionSummary>? history;

  @override
  Widget build(BuildContext context) {
    final streak = _dayStreak(history);
    return GbAppHeader(
      title: 'Workout Log',
      actions: [
        if (streak > 0) GbStreakChip(count: streak),
        GbBellButton(
            onTap: () => showInfoSnack(context, 'No notifications yet'),
            hasUnread: false),
      ],
    );
  }
}

/// Opens the "Start a workout" sheet. Shared so the bottom-nav centre button (and anywhere else) can
/// trigger it. Deliberately NOT isScrollControlled: a full-height modal over a list trips a Flutter
/// semantics crash; the inner [SingleChildScrollView] still scrolls tall content within the normal
/// (capped) sheet height.
Future<void> showStartWorkoutSheet(BuildContext context, WidgetRef ref) {
  final active = ref.read(activeSessionProvider).valueOrNull;
  return showGbSheet<void>(
    context,
    builder: (sheetCtx) => _StartSheet(
      hasActive: active != null,
      activeName: active?.snapshot?.workoutName,
      onAdhoc: () {
        Navigator.of(sheetCtx).pop();
        startAdhoc(context, ref);
      },
      onResume: active == null
          ? null
          : () {
              Navigator.of(sheetCtx).pop();
              context.push('/session/${active.sessionId}');
            },
      onPickPlan: () {
        Navigator.of(sheetCtx).pop();
        context.push('/start');
      },
    ),
  );
}

/// Start-workout bottom sheet — active-session warning, plan picker, and an ad-hoc option.
class _StartSheet extends ConsumerWidget {
  const _StartSheet({
    required this.hasActive,
    required this.activeName,
    required this.onAdhoc,
    required this.onPickPlan,
    required this.onResume,
  });
  final bool hasActive;
  final String? activeName;
  final VoidCallback onAdhoc;
  final VoidCallback onPickPlan;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final plans = ref.watch(assignedPlansProvider);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GbSheetHeader(
              title: 'Start a workout',
              subtitle:
                  'Pick one of your active assignments, or log an ad-hoc session.',
            ),
            const SizedBox(height: AppSpacing.gap),
            if (hasActive) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: gb.warning0,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: gb.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.play_arrow,
                        size: AppSizes.iconMd, color: gb.warning200),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'You have an '),
                          TextSpan(
                              text: 'active ${activeName ?? 'workout'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const TextSpan(
                              text:
                                  ' session. One workout runs at a time — resume it to continue.'),
                        ]),
                        style: TextStyle(
                            fontSize: 12.5, height: 1.4, color: gb.warning300),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              if (onResume != null)
                GbButton(
                    label: 'Resume active session',
                    icon: Icons.play_arrow,
                    full: true,
                    onPressed: onResume),
              const SizedBox(height: AppSpacing.gap),
            ],
            Text('YOUR ASSIGNMENTS',
                style: AppText.eyebrow
                    .copyWith(color: gb.grey400, letterSpacing: 0.7)),
            const SizedBox(height: AppSpacing.xs),
            plans.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: GbSkeleton(height: 64, radius: AppRadius.md)),
              error: (e, _) => Text('Could not load assignments.',
                  style: TextStyle(color: gb.grey500)),
              data: (assigned) {
                if (assigned.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(
                        'No active plans assigned — start an ad-hoc workout below.',
                        style: TextStyle(fontSize: 13, color: gb.grey500)),
                  );
                }
                return Column(
                  children: [
                    for (final a in assigned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: GbTappableRow(
                          leading: GbIconTile(
                              child: Icon(Icons.bolt,
                                  size: 21, color: gb.primary600)),
                          title: a.displayName,
                          titleTrailing: VisBadge(a.visibility),
                          subtitle:
                              '${a.assignment.frequencyDaysPerWeek}×/week · ${a.visibility.label} visibility',
                          onTap: onPickPlan,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            GbTappableRow(
              dashed: true,
              leading: GbIconTile(
                  background: gb.grey25,
                  child: Icon(Icons.add, size: 21, color: gb.grey600)),
              title: 'Ad-hoc workout',
              subtitle: 'No assignment · build it as you go',
              onTap: onAdhoc,
            ),
          ],
        ),
      ),
    );
  }
}
