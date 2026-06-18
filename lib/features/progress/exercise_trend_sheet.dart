import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/progress_models.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/widgets.dart';
import 'lift_widgets.dart';
import 'progress_format.dart';
import 'trend_chart.dart';

/// A quick per-exercise strength trend, openable from the live logger's trend (i) button — so a trainee
/// can peek at "am I progressing on this lift?" WITHOUT leaving the workout. Reuses the per-lift e1RM
/// series + the shared [TrendChart]; an honest empty state covers a brand-new lift or a cardio movement
/// (no e1RM), and "View full details" opens the full `/progress/lift/:id` drill-down.
Future<void> showExerciseTrendSheet(
  BuildContext context, {
  required String exerciseId,
  required String exerciseName,
}) {
  return showGbSheet<void>(
    context,
    scrollable: true,
    builder: (ctx) =>
        _ExerciseTrendSheet(exerciseId: exerciseId, exerciseName: exerciseName),
  );
}

/// Self-contained 12-week e1RM series for the trend sheet. Unlike [exerciseE1rmSeriesProvider] (which
/// inherits the Progress page's selected window — Week by default), this fixes a 12-week look-back so
/// the workout-side peek always shows a meaningful trend regardless of where the Progress tab was left.
final _exerciseTrendProvider = FutureProvider.autoDispose
    .family<ExerciseE1rmSeries, String>((ref, exerciseId) {
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day);
  final from = to.subtract(const Duration(days: 7 * 12));
  return ref
      .read(progressRepositoryProvider)
      .exerciseE1rmSeries(exerciseId, from: from, to: to);
});

class _ExerciseTrendSheet extends ConsumerWidget {
  const _ExerciseTrendSheet(
      {required this.exerciseId, required this.exerciseName});
  final String exerciseId;
  final String exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final series = ref.watch(_exerciseTrendProvider(exerciseId));
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GbSheetHeader(
              title: exerciseName, subtitle: 'Your trend for this exercise'),
          const SizedBox(height: AppSpacing.md),
          series.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Couldn’t load the trend right now.',
                  style: AppText.body.copyWith(color: gb.grey500)),
            ),
            data: (s) => _content(context, s),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ExerciseE1rmSeries s) {
    final gb = context.gb;
    final children = <Widget>[];

    if (s.points.isEmpty) {
      // No qualifying working-set history (a new lift, or a cardio movement with no e1RM) → an honest
      // invite, never a faked chart.
      children.add(Row(
        children: [
          Icon(Icons.show_chart, size: AppSizes.iconLg, color: gb.grey400),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Log a few working sets of this exercise to see your strength trend and PRs.',
              style: AppText.body.copyWith(color: gb.grey600, height: 1.3),
            ),
          ),
        ],
      ));
    } else {
      // Current e1RM headline + the up/flat/down tag, then the shared trend chart (weight first, per the
      // app's "logged weight is the reference, e1RM is the estimate" stance).
      children.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Eyebrow('Current e1RM'),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${fmtKg(s.currentE1rmKg)} kg',
                          style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)
                              .tabular),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            LiftDirectionTag(
              direction: s.direction,
              stalled: s.stalled,
              stallSessions: s.stallSessions,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: TrendChart(
            points: s.points,
            hasTrend: s.hasTrend,
            line: tagColor(gb, s.direction),
            raw: gb.grey400,
            pr: gb.amber,
            label: gb.grey500,
            valueOf: weightValue,
            metricId: 'weight',
          ),
        ),
        if (!s.hasTrend) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Log this exercise a few more times to see the full trend line.',
              style: AppText.meta.copyWith(color: gb.grey500)),
        ],
      ]);
    }

    children.addAll([
      const SizedBox(height: AppSpacing.md),
      GbButton(
        label: 'View full details',
        iconRight: Icons.chevron_right,
        variant: GbButtonVariant.outlined,
        severity: GbButtonSeverity.secondary,
        full: true,
        onPressed: () {
          // Capture the router before popping, then push the full drill-down on the root navigator.
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push('/progress/lift/$exerciseId');
        },
      ),
    ]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
