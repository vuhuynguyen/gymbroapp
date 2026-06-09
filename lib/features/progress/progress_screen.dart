import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/session_models.dart';
import '../../shared/widgets/widgets.dart';
import 'progress_providers.dart';

/// Progress — derived entirely client-side from `GET /sessions` (no reports API). Totals, a weekly
/// volume chart, and recent PR sessions. Mirrors the design `ProgressScreen`: plain header, a row of
/// three KPI tiles, a weekly-volume bar card (current week highlighted with the hero gradient), and
/// a list of recent personal-record sessions.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(progressStatsProvider);

    return Scaffold(
      body: Column(
        children: [
          GbAppHeader(
            title: 'Progress',
            actions: [
              GbBellButton(
                  onTap: () => showInfoSnack(context, 'No notifications yet'))
            ],
          ),
          Expanded(
            child: stats.when(
              loading: () => const GbSkeletonList(count: 4),
              error: (e, _) => ErrorRetry(
                message: e.toString(),
                onRetry: () async => ref.invalidate(progressStatsProvider),
              ),
              data: (s) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(progressStatsProvider);
                  await ref.read(progressStatsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.gap, AppSpacing.screenH, 100),
                  children: [
                    _StatsRow(stats: s),
                    const SizedBox(height: AppSpacing.gap),
                    if (s.weeklyVolumeKg.isNotEmpty) ...[
                      _WeeklyChart(weekly: s.weeklyVolumeKg),
                      const SizedBox(height: AppSpacing.gap),
                    ],
                    const GbSectionTitle('Recent personal records'),
                    const SizedBox(height: AppSpacing.sm),
                    if (s.prSessions.isEmpty)
                      _EmptyPrs()
                    else
                      for (final pr in s.prSessions) ...[
                        _PrRow(pr: pr),
                        const SizedBox(height: AppSpacing.xs + 1),
                      ],
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

/// Format a kg total as a compact thousands label, always 1 decimal with a trailing `.0` stripped
/// ("98.4", "11.4", "10") — matching the design's `fmtVolume`. The chart/eyebrow announce "k".
String _toThousands(double kg) {
  final s = (kg / 1000).toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Relative day label for a PR row trailing.
String _relativeWhen(DateTime? d) {
  if (d == null) return '';
  final local = d.toLocal();
  final today = DateTime.now();
  final dayOnly = DateTime(local.year, local.month, local.day);
  final todayOnly = DateTime(today.year, today.month, today.day);
  final diff = todayOnly.difference(dayOnly).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        [local.weekday - 1];
  }
  return '${local.day}/${local.month}';
}

/// The three KPI tiles: sessions, total volume, PRs.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      children: [
        Expanded(
          child: GbStatTile(
              icon: Icons.history,
              value: '${stats.totalSessions}',
              label: 'SESSIONS'),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: GbStatTile(
            icon: Icons.bar_chart,
            value: _toThousands(stats.totalVolumeKg),
            unit: 'k',
            label: 'TOTAL kg',
            accent: gb.primary500,
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: GbStatTile(
            icon: Icons.emoji_events_outlined,
            value: '${stats.totalPrs}',
            label: 'PRS',
            accent: gb.amber,
          ),
        ),
      ],
    );
  }
}

/// Weekly volume bar chart (design `ProgressScreen` chart). Values are in thousands of kg
/// (the eyebrow announces the unit); the most-recent week uses the hero gradient + blue glow,
/// earlier weeks a muted primary tint.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.weekly});
  final List<MapEntry<DateTime, double>> weekly;

  @override
  Widget build(BuildContext context) {
    final max = weekly.fold<double>(1, (m, e) => e.value > m ? e.value : m);
    return GbCard(
      padding: const EdgeInsets.all(AppSpacing.heroPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Weekly volume · k kg'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 124,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weekly.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: _Bar(
                        value: weekly[i].value,
                        max: max,
                        label: '${weekly[i].key.day}/${weekly[i].key.month}',
                        isLast: i == weekly.length - 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single chart column: tabular value, the bar, then the week date.
class _Bar extends StatelessWidget {
  const _Bar(
      {required this.value,
      required this.max,
      required this.label,
      required this.isLast});
  final double value;
  final double max;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _toThousands(value),
          style: AppText.label
              .copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isLast ? gb.primary700 : gb.grey500,
              )
              .tabular,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          height: (value / max * 92).clamp(2, 92),
          decoration: BoxDecoration(
            gradient: isLast ? GbColors.heroGradient : null,
            color: isLast ? null : AppPalette.primary100,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10), bottom: Radius.circular(4)),
            boxShadow: isLast ? AppShadows.blueSm : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Eyebrow(label),
      ],
    );
  }
}

/// A recent personal-record session row — amber trophy tile, name, PR count, and a "when" label.
class _PrRow extends StatelessWidget {
  const _PrRow({required this.pr});
  final SessionSummary pr;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final when = _relativeWhen(pr.completedAt ?? pr.startedAt);
    return GbTappableRow(
      leading: GbIconTile(
        background: gb.amberSoft,
        child: Icon(Icons.emoji_events, size: AppSizes.iconXl, color: gb.amber),
      ),
      title: pr.programName ?? pr.workoutName ?? 'Session',
      subtitle: '${pr.prCount} PR${pr.prCount == 1 ? '' : 's'}',
      trailing: when.isEmpty
          ? const SizedBox.shrink()
          : Text(when, style: AppText.meta.copyWith(color: gb.grey400)),
      onTap: () => context.push('/session-detail/${pr.id}?me=1'),
    );
  }
}

/// Muted "no PRs" line shown when the trainee has no PR sessions yet.
class _EmptyPrs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        'No PRs yet — keep training!',
        style: AppText.body.copyWith(color: context.gb.grey500),
      ),
    );
  }
}
