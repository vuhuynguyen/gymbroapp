import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/coach_models.dart';
import '../../data/models/progress_models.dart';
import '../../shared/widgets/widgets.dart';
import '../progress/lift_widgets.dart';
import '../progress/progress_format.dart';
import '../progress/trend_chart.dart';
import 'coach_providers.dart';
import 'coach_widgets.dart';

/// Coach per-client strength detail (Phase 2b) — opened from the roster. Leads with the verdict
/// (name + status chip + adherence ring), then the per-client e1RM trends, one card per key lift.
///
/// Both the verdict and the trends are TENANT-SCOPED (own gym only) — the strength series is built
/// from the coach's tenant-scoped sessions via a SEPARATE handler (EF tenant filter ON), never the
/// trainee's cross-gym self path (COACH-VS-TRAINEE.md §4). The trend chart is the SAME shared
/// [TrendChart] the trainee per-lift drill-down uses (Phase 2a), over the coach `clientStrength` data.
///
/// **No body-metric card.** There is no coach endpoint for another user's `MetricEntry` (weight/sleep)
/// — it is private/self-scoped by design. Absence is the honest design; an empty placeholder reads as
/// broken (COACH-VS-TRAINEE.md §3). This screen renders no body-data tile at all.
class ClientStrengthScreen extends ConsumerWidget {
  const ClientStrengthScreen({required this.clientId, this.clientName, super.key});
  final String clientId;
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.gb.grey0,
      body: Column(
        children: [
          GbDetailHeader(
            title: clientName ?? 'Client',
            onLeading: () => context.canPop() ? context.pop() : context.go('/coach-progress'),
          ),
          Expanded(child: _Body(clientId: clientId, clientName: clientName)),
        ],
      ),
    );
  }
}

ClientStatus? _findClient(Roster r, String id) {
  for (final c in r.items) {
    if (c.traineeId == id) return c;
  }
  return null;
}

/// The per-client detail body — one scroll view. The strength section resolves its own async state
/// INLINE (a non-scrolling skeleton on load) so the Workload card below stays mounted across a
/// strength refetch / gym switch. If the card were nested inside the strength `data` branch, a
/// refetch would unmount it and its `autoDispose` provider would fire an extra `/load` read.
class _Body extends ConsumerWidget {
  const _Body({required this.clientId, this.clientName});
  final String clientId;
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strength = ref.watch(clientStrengthProvider(clientId));
    final roster = ref.watch(coachRosterProvider);
    // The verdict header comes from the roster the coach just came through (already loaded); if it's
    // not available (deep link / refetch) the header degrades to name-only, never a fake status.
    final status =
        roster.maybeWhen(data: (r) => _findClient(r, clientId), orElse: () => null);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(clientStrengthProvider(clientId));
        ref.invalidate(clientLoadProvider(clientId));
        await ref.read(clientStrengthProvider(clientId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, 32),
        children: [
          _VerdictHeader(
              clientName: clientName ?? status?.displayName ?? 'Client',
              status: status),
          const SizedBox(height: AppSpacing.md),
          const GbSectionTitle('Strength trends'),
          const SizedBox(height: AppSpacing.xs),
          Text('Per-lift e1RM in this gym only.',
              style: AppText.meta.copyWith(color: context.gb.grey500)),
          const SizedBox(height: AppSpacing.sm),
          // Strength state handled inline (non-scrolling skeleton) so the Workload card stays mounted.
          strength.when(
            loading: () => Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                    child: GbSkeleton(height: 132, radius: AppRadius.md),
                  ),
              ],
            ),
            error: (e, _) => ErrorRetry(
              message: e is ApiException ? e.message : 'Something went wrong.',
              onRetry: () async => ref.invalidate(clientStrengthProvider(clientId)),
            ),
            data: (lifts) => lifts.isEmpty
                ? const _NoStrength()
                : Column(
                    children: [
                      for (final lift in lifts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                          child: _LiftTrendCard(series: lift),
                        ),
                    ],
                  ),
          ),
          // Workload (acute-vs-chronic) — its own provider, a permanent sibling BELOW the strength
          // section (Decision D14). Always mounted, so a strength refetch never unmounts it; it owns
          // its own loading/quiet states and never blocks the trends above.
          const SizedBox(height: AppSpacing.sm),
          const GbSectionTitle('Workload'),
          const SizedBox(height: AppSpacing.sm),
          _WorkloadCard(clientId: clientId),
        ],
      ),
    );
  }
}

/// The acute-vs-chronic workload card (Phase 4 / Decision D14). Renders the client's 7-day acute volume
/// and chronic weekly-average volume as **two separate bars** (zero-baseline, shared scale, labeled in
/// kg) plus a **soft** trend chip ("Ramping up" / "Steady" / "Easing off") — never an ACWR ratio, never
/// a number presented as an injury threshold (COACH-VS-TRAINEE.md §3, audit R10).
///
/// Watches [clientLoadProvider] itself so it owns its loading/error states: a skeleton while loading, a
/// quiet card on error (it must NOT take down the strength trends above with an `ErrorRetry`). A
/// non-member id 403/404s server-side → the quiet card, never a fake "steady".
class _WorkloadCard extends ConsumerWidget {
  const _WorkloadCard({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(clientLoadProvider(clientId));
    return load.when(
      loading: () => const _WorkloadSkeleton(),
      // Quiet on error — the workload is a supporting signal; a failed /load must never block or
      // error the strength trends. No alarm, no retry button competing with the page.
      error: (_, __) => const _WorkloadQuiet(
        text: "Workload isn't available right now.",
      ),
      data: (data) =>
          data.hasData ? _WorkloadBars(load: data) : const _WorkloadEmpty(),
    );
  }
}

/// The populated workload card: two labeled bars + a soft trend chip + the mandatory scope caption.
class _WorkloadBars extends StatelessWidget {
  const _WorkloadBars({required this.load});
  final AcuteChronicLoad load;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final unit = (load.unit?.trim().isNotEmpty ?? false) ? load.unit!.trim() : 'kg';
    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Training volume',
                    style: AppText.rowTitle.copyWith(color: gb.grey900)),
              ),
              const SizedBox(width: AppSpacing.sm),
              _TrendChip(trend: load.trend),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _LoadBar(
            label: 'This week',
            sublabel: 'last 7 days',
            valueKg: load.acuteVolumeKg,
            peakKg: load.peakKg,
            unit: unit,
            color: gb.primary500,
            track: gb.grey25,
          ),
          const SizedBox(height: AppSpacing.gap),
          _LoadBar(
            label: 'Weekly average',
            sublabel: 'last 4 weeks',
            valueKg: load.chronicWeeklyVolumeKg,
            peakKg: load.peakKg,
            unit: unit,
            color: gb.grey400,
            track: gb.grey25,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('7-day vs 4-week weekly average · this gym only',
              style: AppText.meta.copyWith(color: gb.grey500)),
        ],
      ),
    );
  }
}

/// One labeled horizontal bar — name + sublabel on the left, the kg value on the right, a zero-baseline
/// bar beneath (scaled to the taller of the two so the acute/chronic comparison is honest). No ratio.
class _LoadBar extends StatelessWidget {
  const _LoadBar({
    required this.label,
    required this.sublabel,
    required this.valueKg,
    required this.peakKg,
    required this.unit,
    required this.color,
    required this.track,
  });

  final String label;
  final String sublabel;
  final double valueKg;
  final double peakKg;
  final String unit;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(color: gb.grey700, fontSize: 12.5)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(sublabel, style: AppText.meta.copyWith(color: gb.grey400)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('${fmtKg(valueKg)} $unit',
                style: AppText.label.copyWith(color: gb.grey900, fontSize: 13).tabular),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 12,
          width: double.infinity,
          child: CustomPaint(
            painter: _LoadBarPainter(
              fraction: peakKg <= 0 ? 0 : (valueKg / peakKg).clamp(0.0, 1.0),
              color: color,
              track: track,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a single zero-baseline horizontal bar: a faint full-width track, then a fill whose width is
/// `fraction` of the available width. The two bars share one `peakKg` scale (the taller = full width),
/// so the acute/chronic comparison is read off the bar lengths directly — never a ratio number.
class _LoadBarPainter extends CustomPainter {
  _LoadBarPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final trackRect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(trackRect, Paint()..color = track);

    final w = (size.width * fraction.clamp(0.0, 1.0));
    if (w <= 0) return;
    // A minimum visible nub so a tiny-but-nonzero value still registers as a bar.
    final fillW = math.max(w, math.min(size.height, size.width));
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, fillW.clamp(0.0, size.width), size.height),
      radius,
    );
    canvas.drawRRect(fillRect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LoadBarPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// The soft, non-medical trend chip. Gentle tones only — `ramping` is amber (a nudge, not an alarm),
/// `detraining` is a calm grey, `steady` is the success/emerald "all good". Never red, never a claim.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});
  final LoadTrend trend;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg, icon, label) = switch (trend) {
      LoadTrend.ramping => (gb.amberSoft, gb.amberInk, Icons.trending_up, 'Ramping up'),
      LoadTrend.detraining => (gb.grey0, gb.grey600, Icons.trending_down, 'Easing off'),
      LoadTrend.steady => (gb.emeraldSoft, gb.emeraldInk, Icons.trending_flat, 'Steady'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconXs, color: fg),
          const SizedBox(width: AppSpacing.xxs),
          Text(label, style: AppText.label.copyWith(color: fg, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// The honest empty state — the client has no logged volume in this gym yet. A quiet card (not an
/// error, not two empty bars + a misleading "steady" chip).
class _WorkloadEmpty extends StatelessWidget {
  const _WorkloadEmpty();

  @override
  Widget build(BuildContext context) =>
      const _WorkloadQuiet(text: 'No training volume logged in this gym yet.');
}

/// A quiet (not-an-error) workload placeholder — used for the empty and error states so neither
/// competes with the strength trends above.
class _WorkloadQuiet extends StatelessWidget {
  const _WorkloadQuiet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GbCard(
      child: Text(text, style: AppText.body.copyWith(color: context.gb.grey500)),
    );
  }
}

/// A minimal skeleton while the workload loads — quiet shimmer-free placeholder bars so the section
/// doesn't pop in. Never a spinner that would imply the page is blocked on it.
class _WorkloadSkeleton extends StatelessWidget {
  const _WorkloadSkeleton();

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    Widget barRow() => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.gap),
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: gb.grey25,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 14,
            width: 120,
            decoration: BoxDecoration(
              color: gb.grey25,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          barRow(),
          barRow(),
        ],
      ),
    );
  }
}

/// The verdict header — avatar, name, the roster status chip, and the adherence ring (`done/goal`).
/// Leads with the recommendation before any chart loads (COACH-VS-TRAINEE.md §3).
class _VerdictHeader extends StatelessWidget {
  const _VerdictHeader({required this.clientName, required this.status});
  final String clientName;
  final ClientStatus? status;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final s = status;
    final initial = clientName.trim().isNotEmpty ? clientName.trim()[0].toUpperCase() : '?';

    return GbCard(
      child: Row(
        children: [
          Avatar(initial: initial, size: 52, ring: true),
          const SizedBox(width: AppSpacing.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clientName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: gb.ink)),
                const SizedBox(height: 4),
                if (s != null) RosterStatusBadge(status: s.status) else const _StatusUnknown(),
              ],
            ),
          ),
          if (s != null && s.hasGoal) ...[
            const SizedBox(width: AppSpacing.sm),
            GbRing(
              value: s.ringValue,
              size: 48,
              stroke: 5,
              gradient: const [AppPalette.primary200, AppPalette.primary700],
              child: Text('${s.completedThisWeek}/${s.weeklyGoal}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: gb.grey900)
                      .tabular),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusUnknown extends StatelessWidget {
  const _StatusUnknown();

  @override
  Widget build(BuildContext context) =>
      Text('In this gym', style: AppText.meta.copyWith(color: context.gb.grey500));
}

/// "No qualifying lifts yet" — the honest empty when the client has logged no working sets that
/// clear the e1RM honesty gate in this gym. Never a faked chart.
class _NoStrength extends StatelessWidget {
  const _NoStrength();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: EmptyState(
        icon: Icons.show_chart,
        title: 'No strength data yet',
        subtitle: 'Once this client logs a few working sets in this gym, '
            'their e1RM trends will appear here.',
      ),
    );
  }
}

/// One lift's trend card — the lift name + current e1RM + direction tag, then the shared [TrendChart]
/// over this client's tenant-scoped session-best series. Mirrors the trainee drill-down card visuals
/// but stacked per lift (the coach scans several key lifts at once).
class _LiftTrendCard extends StatelessWidget {
  const _LiftTrendCard({required this.series});
  final ExerciseE1rmSeries series;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final lineColor = tagColor(gb, series.direction);
    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (series.exerciseName?.trim().isNotEmpty ?? false)
                          ? series.exerciseName!.trim()
                          : 'Lift',
                      style: AppText.rowTitle.copyWith(color: gb.grey900),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(fmtKg(series.currentE1rmKg),
                            style: AppText.statNumber.copyWith(fontSize: 22, color: gb.ink)),
                        Text(' kg e1RM',
                            style: AppText.meta.copyWith(color: gb.grey400)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              LiftDirectionTag(
                direction: series.direction,
                stalled: series.stalled,
                stallSessions: series.stallSessions,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: TrendChart(
              points: series.points,
              hasTrend: series.hasTrend,
              line: lineColor,
              raw: gb.grey400,
              pr: gb.amber,
              label: gb.grey500,
            ),
          ),
          if (!series.hasTrend) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Not enough sessions in this gym to chart a trend yet.',
                style: AppText.meta.copyWith(color: gb.grey500)),
          ],
        ],
      ),
    );
  }
}

