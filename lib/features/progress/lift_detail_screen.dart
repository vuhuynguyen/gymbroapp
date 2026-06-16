import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/exercise_models.dart';
import '../../data/models/progress_models.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../shared/widgets/widgets.dart';
import '../session/live_session_screen.dart' show openExerciseGuide;
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
    // The catalog gives the muscle breakdown + a guide entrypoint (loads independently; null is fine).
    final catalog = ref.watch(exerciseCatalogProvider).valueOrNull?[exerciseId];

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
                child: _Body(
                  series: s,
                  catalog: catalog,
                  onGuide: () => openExerciseGuide(
                    context,
                    exerciseId: exerciseId,
                    exerciseName: (s.exerciseName?.trim().isNotEmpty ?? false)
                        ? s.exerciseName!.trim()
                        : 'Exercise',
                    repository: ref.read(exerciseRepositoryProvider),
                    catalog: catalog,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The data body — a scrollable so pull-to-refresh stays available in every state. The exercise meta +
/// guide sit at the top (always available, even with thin trend data); the trend + recent-sessions
/// table follow once there are logged points.
class _Body extends StatelessWidget {
  const _Body(
      {required this.series, required this.onGuide, this.catalog});
  final ExerciseE1rmSeries series;
  final ExerciseSummary? catalog;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final hasData = series.points.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.gap, AppSpacing.screenH, 32),
      children: [
        _ExerciseMetaCard(catalog: catalog, onGuide: onGuide),
        const SizedBox(height: AppSpacing.gap),
        if (!hasData)
          // No qualifying points yet → honest invite, not a faked chart (DRILL-DOWNS §1).
          GbCard(
            child: Row(
              children: [
                Icon(Icons.show_chart, size: AppSizes.iconLg, color: gb.grey400),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Log a few working sets of this lift to see your e1RM trend and PR markers.',
                    style: AppText.body.copyWith(color: gb.grey600, height: 1.3),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _HeaderStrip(series: series),
          const SizedBox(height: AppSpacing.gap),
          _TrendCard(series: series),
          if (series.stalled && series.stallSessions > 0) ...[
            const SizedBox(height: AppSpacing.gap),
            _StallNote(stallSessions: series.stallSessions),
          ],
          const SizedBox(height: AppSpacing.gap),
          _RecentSessions(points: series.points),
        ],
      ],
    );
  }
}

/// Exercise meta — muscle involvement (primary / secondary) + type/equipment, and the "View guide"
/// entrypoint into the Form Coach sheet. Muscle chips come from the catalog; the guide always shows.
class _ExerciseMetaCard extends StatelessWidget {
  const _ExerciseMetaCard({required this.onGuide, this.catalog});
  final ExerciseSummary? catalog;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final c = catalog;
    final primary =
        c?.muscles.where((m) => m.isPrimary).map((m) => m.name).toList() ??
            const <String>[];
    final secondary =
        c?.muscles.where((m) => !m.isPrimary).map((m) => m.name).toList() ??
            const <String>[];
    // Fall back to the single primary group if the detailed list is absent (older payload).
    final primaryChips = primary.isNotEmpty
        ? primary
        : [if (c?.muscleGroup.isNotEmpty ?? false) c!.muscleGroup];

    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (primaryChips.isNotEmpty || secondary.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in primaryChips) _MuscleChip(m, primary: true),
                for (final m in secondary) _MuscleChip(m, primary: false),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          if (c != null && c.type.isNotEmpty) ...[
            Text(
              '${c.type}${c.equipment.isNotEmpty ? ' · ${c.equipment}' : ''}',
              style: AppText.meta.copyWith(color: gb.grey500),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          GbButton(
            label: 'View exercise guide',
            icon: Icons.menu_book_outlined,
            variant: GbButtonVariant.outlined,
            size: GbButtonSize.sm,
            full: true,
            onPressed: onGuide,
          ),
        ],
      ),
    );
  }
}

/// A muscle pill — brand-tinted for a primary mover, grey for a secondary one.
class _MuscleChip extends StatelessWidget {
  const _MuscleChip(this.label, {required this.primary});
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final fg = primary ? gb.primary700 : gb.grey600;
    final bg = primary ? gb.primary600.withValues(alpha: 0.10) : gb.grey25;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// The most recent sessions for this lift (newest first, up to 8) — date · top set · e1RM · PR — so
/// progress over time is readable as a table, not only as the chart.
class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.points});
  final List<E1rmSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final recent = points.reversed.take(8).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GbSectionTitle('Recent sessions', count: recent.length),
        const SizedBox(height: AppSpacing.sm),
        GbCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            children: [
              for (final (i, p) in recent.indexed) ...[
                if (i > 0) Divider(height: 1, color: gb.grey25),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 74,
                        child: Text(_shortDate(p.date),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: gb.grey700)),
                      ),
                      Expanded(
                        child: Text(
                          p.topSetWeightKg != null
                              ? '${fmtKg(p.topSetWeightKg!)} kg × ${p.topSetReps ?? '—'}'
                              : '—',
                          style: AppText.meta.copyWith(color: gb.grey600).tabular,
                        ),
                      ),
                      Text('${fmtKg(p.sessionBestE1rmKg)} kg',
                          style: AppText.mono(const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700))
                              .copyWith(color: gb.grey900)),
                      if (p.isPr) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const PrChip(small: true),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// Short "15 Jun" date for the recent-sessions table; '—' when the point has no date.
String _shortDate(DateTime? d) =>
    d == null ? '—' : '${d.day} ${_months[d.month - 1]}';

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
                if (_lastTopSet(series) != null) ...[
                  const SizedBox(height: 2),
                  Text(_lastTopSet(series)!,
                      style: AppText.meta.copyWith(color: gb.grey500).tabular),
                ],
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

/// The primary visualization — a bold line over faint raw session points with amber PR markers,
/// min/max y labels, and a "log N more" gate below 4 points (DRILL-DOWNS §1, D11: no chart lib).
/// A toggle switches the plotted metric between estimated 1RM and the actual top-set weight logged.
class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.series});
  final ExerciseE1rmSeries series;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  bool _weight = false; // false = e1RM, true = top-set weight

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final series = widget.series;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GbSectionTitle(_weight ? 'Weight trend' : 'e1RM trend'),
            const Spacer(),
            _MetricToggle(
              weight: _weight,
              onChanged: (w) => setState(() => _weight = w),
            ),
          ],
        ),
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
                  valueOf: _weight ? weightValue : e1rmValue,
                  metricId: _weight ? 'weight' : 'e1rm',
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
                _Legend(
                  line: tagColor(gb, series.direction),
                  pr: gb.amber,
                  lineLabel: _weight ? 'Weight' : 'e1RM',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static int _needMore(int n) => math.max(1, 4 - n);
}

/// Two-pill segmented toggle to switch the trend metric between e1RM and logged weight.
class _MetricToggle extends StatelessWidget {
  const _MetricToggle({required this.weight, required this.onChanged});
  final bool weight;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    Widget pill(String text, bool selected, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? gb.primary600 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text,
                style: AppText.meta.copyWith(
                    color: selected ? Colors.white : gb.grey500,
                    fontWeight: FontWeight.w700)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: gb.grey0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gb.borderCard),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        pill('e1RM', !weight, () => onChanged(false)),
        pill('Weight', weight, () => onChanged(true)),
      ]),
    );
  }
}

/// A tiny inline legend so the amber PR markers and the trend line read unambiguously.
class _Legend extends StatelessWidget {
  const _Legend({required this.line, required this.pr, this.lineLabel = 'e1RM'});
  final Color line;
  final Color pr;
  final String lineLabel;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Row(
      children: [
        _swatch(line, lineLabel, gb),
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

// ── Formatting helpers ───────────────────────────────────────────────────────

/// "+4.2 kg vs your trailing 4 weeks" / "−1.0 kg …" / "No change …". Never red copy — the tag carries
/// the direction color; this caption stays neutral.
/// "Last top set: 22.5 kg × 6" from the most recent point — the actual weight lifted, beside the e1RM.
String? _lastTopSet(ExerciseE1rmSeries s) {
  if (s.points.isEmpty) return null;
  final p = s.points.last;
  if (p.topSetWeightKg == null) return null;
  final reps = p.topSetReps != null ? ' × ${p.topSetReps}' : '';
  return 'Last top set: ${fmtKg(p.topSetWeightKg!)} kg$reps';
}

String _deltaCaption(ExerciseE1rmSeries s) {
  final d = s.deltaKgVsTrailing4w;
  if (d.abs() < 0.05) return 'No change vs your trailing 4 weeks';
  final sign = d > 0 ? '+' : '−';
  return '$sign${fmtKg(d.abs())} kg vs your trailing 4 weeks';
}
