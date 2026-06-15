import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/app_time_zone.dart';
import '../../data/models/session_models.dart';
import '../../domain/enums.dart';
import '../../domain/session_grouping.dart' show mondayOf;
import '../../shared/widgets/widgets.dart';

/// The Progress segment of the coach's client monitor — the client's weekly volume trend, recent PRs,
/// and a client-logged body-data note. Volume/PRs are derived from the same sessions the monitor
/// already loaded (no extra fetch); body metrics are self-reported via the trainee's daily check-in.
///
/// Stateful so the weekly-volume bucketing + PR filtering run **once per session list**, not on every
/// rebuild: the host (`_ClientTabs`) `setState`s on each Workouts/Nutrition/Progress segment toggle,
/// which would otherwise re-run this O(n) derivation over the immutable `sessions` each time. The
/// derived values are cached and only recomputed when the `sessions` identity changes.
class ClientProgressPanel extends StatefulWidget {
  const ClientProgressPanel({required this.sessions, super.key});
  final List<SessionSummary> sessions;

  @override
  State<ClientProgressPanel> createState() => _ClientProgressPanelState();
}

class _ClientProgressPanelState extends State<ClientProgressPanel> {
  late List<SessionSummary> _sessions;
  late List<MapEntry<DateTime, double>> _weekly;
  late List<SessionSummary> _prs;

  @override
  void initState() {
    super.initState();
    _derive(widget.sessions);
  }

  @override
  void didUpdateWidget(covariant ClientProgressPanel old) {
    super.didUpdateWidget(old);
    // Re-derive only when a genuinely different session list arrives (the host passes the same
    // immutable list across segment toggles, so this is an identity check, not a deep compare).
    if (!identical(widget.sessions, _sessions)) _derive(widget.sessions);
  }

  void _derive(List<SessionSummary> sessions) {
    _sessions = sessions;
    final completed =
        sessions.where((s) => s.status == SessionStatus.completed).toList();
    _weekly = _weeklyVolume(completed);
    _prs = completed.where((s) => s.prCount > 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final weekly = _weekly;
    final prs = _prs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weekly.isNotEmpty) ...[
          _WeeklyVolumeChart(weekly: weekly),
          const SizedBox(height: AppSpacing.gap),
        ],
        const GbSectionTitle('Recent personal records'),
        const SizedBox(height: AppSpacing.sm),
        if (prs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('No PRs logged yet.', style: TextStyle(fontSize: 13, color: gb.grey400)),
          )
        else
          for (final pr in prs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs + 1),
              child: GbTappableRow(
                onTap: () => context.push('/session-detail/${pr.id}'),
                leading: GbIconTile(
                  background: gb.amberSoft,
                  child: Icon(Icons.emoji_events, size: AppSizes.iconXl, color: gb.amber),
                ),
                title: pr.programName ?? pr.workoutName ?? 'Session',
                subtitle: '${pr.prCount} PR${pr.prCount == 1 ? '' : 's'}',
              ),
            ),
        const SizedBox(height: AppSpacing.md),
        const GbSectionTitle('Body data'),
        const SizedBox(height: AppSpacing.sm),
        GbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _bodyStat(context, Icons.monitor_weight_outlined, 'Weight', '—')),
                  Expanded(child: _bodyStat(context, Icons.bedtime_outlined, 'Sleep', '—')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Body data is client-logged via the daily check-in — self-reported, not verified.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: gb.grey400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bodyStat(BuildContext context, IconData icon, String label, String value) {
    final gb = context.gb;
    return Row(
      children: [
        Icon(icon, size: AppSizes.iconLg, color: gb.grey400),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Eyebrow(label),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: gb.ink)),
          ],
        ),
      ],
    );
  }

  /// Sum completed-session volume into the last six Monday-anchored weeks (oldest → newest).
  static List<MapEntry<DateTime, double>> _weeklyVolume(List<SessionSummary> completed) {
    final buckets = <DateTime, double>{};
    for (final s in completed) {
      final instant = s.completedAt ?? s.startedAt;
      if (instant == null) continue;
      // Bucket in the trainee's captured zone so weeks align to the trainee's calendar, not the coach's.
      final monday = mondayOf(AppTimeZone.wallClock(instant, s.clientTimezone));
      buckets[monday] = (buckets[monday] ?? 0) + s.totalVolumeKg;
    }
    if (buckets.isEmpty) return const [];
    final keys = buckets.keys.toList()..sort();
    final recent = keys.length > 6 ? keys.sublist(keys.length - 6) : keys;
    return [for (final k in recent) MapEntry(k, buckets[k]!)];
  }
}

String _toThousands(double kg) {
  final s = (kg / 1000).toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Weekly-volume bar chart mirroring the Progress screen's visual (latest week uses the hero gradient
/// + blue glow). Kept local to the coach panel so the trainee Progress screen stays untouched (1:1).
class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.weekly});
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

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.label, required this.isLast});
  final double value;
  final double max;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    // Value label + bar live inside an Expanded and are bottom-aligned; the bar height is a fraction
    // of the *available* space (computed from the box, not a fixed 84) so the column can never
    // overflow regardless of font metrics — the bug the old fixed-height bar hit.
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const labelH = 22.0, gap = 4.0;
              final avail = (c.maxHeight - labelH - gap).clamp(2.0, c.maxHeight);
              final h = ((value / max) * avail).clamp(2.0, avail);
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_toThousands(value),
                      style: AppText.label
                          .copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isLast ? gb.primary700 : gb.grey500)
                          .tabular),
                  const SizedBox(height: gap),
                  Container(
                    width: double.infinity,
                    height: h,
                    decoration: BoxDecoration(
                      gradient: isLast ? GbColors.heroGradient : null,
                      color: isLast ? null : AppPalette.primary100,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10), bottom: Radius.circular(4)),
                      boxShadow: isLast ? AppShadows.blueSm : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Eyebrow(label),
      ],
    );
  }
}
