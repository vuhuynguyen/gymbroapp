import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/progress_models.dart';
import '../../shared/widgets/widgets.dart';
import 'lift_widgets.dart';
import 'progress_format.dart';
import 'progress_providers.dart';
import 'trend_chart.dart';

/// Per-lift strength drill-down (DRILL-DOWNS §1) — the diagnostic behind a home Strength row.
/// Home says *"Bench trending up"*; this screen answers *push, hold, or change this lift?* via the
/// full e1RM trend with PR markers, the direction verdict restated, and a stall callout.
///
/// Full-screen route `/progress/lift/:exerciseId` (above the shell, tab bar hidden). Watches
/// [exerciseE1rmSeriesProvider]; renders skeleton / ErrorRetry / "not enough data yet" / the chart.
/// Tokens only — visual design arrives later; this is functional + restylable.
class LiftDetailScreen extends ConsumerWidget {
  const LiftDetailScreen({required this.exerciseId, super.key});
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(exerciseE1rmSeriesProvider(exerciseId));

    // Prefer the loaded lift name in the header once it arrives; a neutral title before.
    final title = series.maybeWhen(
      data: (s) => (s.exerciseName?.trim().isNotEmpty ?? false)
          ? s.exerciseName!.trim()
          : 'Lift detail',
      orElse: () => 'Lift detail',
    );

    return Scaffold(
      body: Column(
        children: [
          GbDetailHeader(
            title: title,
            onLeading: () =>
                context.canPop() ? context.pop() : context.go('/progress'),
          ),
          Expanded(
            child: series.when(
              loading: () => const GbSkeletonList(count: 3),
              error: (e, _) => ErrorRetry(
                message: e is ApiException ? e.message : 'Something went wrong.',
                onRetry: () async =>
                    ref.invalidate(exerciseE1rmSeriesProvider(exerciseId)),
              ),
              data: (s) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(exerciseE1rmSeriesProvider(exerciseId));
                  await ref
                      .read(exerciseE1rmSeriesProvider(exerciseId).future);
                },
                child: _Body(series: s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The data body — a scrollable so pull-to-refresh stays available in every state, including empty.
class _Body extends StatelessWidget {
  const _Body({required this.series});
  final ExerciseE1rmSeries series;

  @override
  Widget build(BuildContext context) {
    // No qualifying points at all → honest empty invite (DRILL-DOWNS §1), not a faked chart.
    if (series.points.isEmpty) {
      return const _ScrollableCenter(
        child: EmptyState(
          icon: Icons.show_chart,
          title: 'Not enough data yet',
          subtitle:
              'Log a few working sets of this lift to see your e1RM trend and PR markers.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, 32),
      children: [
        _HeaderStrip(series: series),
        const SizedBox(height: AppSpacing.gap),
        _TrendCard(series: series),
        if (series.stalled && series.stallSessions > 0) ...[
          const SizedBox(height: AppSpacing.gap),
          _StallNote(stallSessions: series.stallSessions),
        ],
      ],
    );
  }
}

// ── Header strip: current e1RM · direction tag · Δ note ──────────────────────

/// Restates the home verdict at the top of the drill-down: the current e1RM headline number, the
/// up/flat/down tag (the Phase-1 style), and a quiet Δ-vs-trailing-4-weeks caption.
class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.series});
  final ExerciseE1rmSeries series;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Eyebrow('Current e1RM'),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(fmtKg(series.currentE1rmKg),
                        style: AppText.statNumber
                            .copyWith(fontSize: 30, color: gb.ink)),
                    Text(' kg',
                        style: AppText.label.copyWith(
                            fontSize: 13, color: gb.grey400)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(_deltaCaption(series),
                    style: AppText.meta.copyWith(color: gb.grey500).tabular),
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
    );
  }
}

/// A quiet stall callout — flatness framed as an observation, never a fatigue/overtraining verdict
/// (DRILL-DOWNS §1). Neutral grey, never red.
class _StallNote extends StatelessWidget {
  const _StallNote({required this.stallSessions});
  final int stallSessions;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      color: gb.grey0,
      shadow: false,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: AppSizes.iconLg, color: gb.grey500),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Flat for $stallSessions sessions — a good moment to deload, swap, '
              'or change the rep scheme.',
              style: AppText.body.copyWith(color: gb.grey600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trend card: the e1RM CustomPaint chart ───────────────────────────────────

/// The primary visualization — a bold e1RM line over faint raw session points with amber PR markers,
/// min/max y labels, and a "log N more" gate below 4 points (DRILL-DOWNS §1, D11: no chart lib).
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.series});
  final ExerciseE1rmSeries series;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GbSectionTitle('e1RM trend'),
        const SizedBox(height: AppSpacing.sm),
        GbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: TrendChart(
                  points: series.points,
                  hasTrend: series.hasTrend,
                  line: tagColor(gb, series.direction),
                  raw: gb.grey400,
                  pr: gb.amber,
                  label: gb.grey500,
                ),
              ),
              if (!series.hasTrend) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Log this lift ${_needMore(series.points.length)} more '
                  '${_needMore(series.points.length) == 1 ? 'time' : 'times'} '
                  'to see your trend.',
                  style: AppText.meta.copyWith(color: gb.grey500),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                _Legend(line: tagColor(gb, series.direction), pr: gb.amber),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static int _needMore(int n) => math.max(1, 4 - n);
}

/// A tiny inline legend so the amber PR markers and the trend line read unambiguously.
class _Legend extends StatelessWidget {
  const _Legend({required this.line, required this.pr});
  final Color line;
  final Color pr;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      children: [
        _swatch(line, 'e1RM', gb),
        const SizedBox(width: AppSpacing.md),
        _swatch(pr, 'PR', gb, dot: true),
      ],
    );
  }

  Widget _swatch(Color color, String label, GbColors gb, {bool dot = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot ? 8 : 14,
          height: dot ? 8 : 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(dot ? 4 : 2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppText.meta.copyWith(color: gb.grey500)),
      ],
    );
  }
}

// ── Shared scaffolding ───────────────────────────────────────────────────────

/// Centers [child] inside an always-scrollable viewport so pull-to-refresh works in empty states.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ── Formatting helpers ───────────────────────────────────────────────────────

/// "+4.2 kg vs your trailing 4 weeks" / "−1.0 kg …" / "No change …". Never red copy — the tag carries
/// the direction color; this caption stays neutral.
String _deltaCaption(ExerciseE1rmSeries s) {
  final d = s.deltaKgVsTrailing4w;
  if (d.abs() < 0.05) return 'No change vs your trailing 4 weeks';
  final sign = d > 0 ? '+' : '−';
  return '$sign${fmtKg(d.abs())} kg vs your trailing 4 weeks';
}
