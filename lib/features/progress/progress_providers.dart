import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/progress_models.dart';
import '../../data/repositories/progress_repository.dart';

/// The trainee Progress home — one self-scoped read (`GET /api/me/progress/overview`).
///
/// `autoDispose`: the tab refetches naturally on re-entry (cheap, uncached, always fresh — PHASE-1
/// §4/§6). Pull-to-refresh invalidates this provider and awaits its future.
final progressOverviewProvider =
    FutureProvider.autoDispose<ProgressOverview>((ref) async {
  return ref.read(progressRepositoryProvider).overview();
});

/// Per-lift e1RM series for the strength drill-down (`/api/me/exercises/{id}/e1rm-series`), keyed by
/// exercise id. `autoDispose.family`: each lift detail is fetched on open and dropped on close —
/// fresh every visit, like the overview. The drill-down screen renders loading/error/empty/data.
final exerciseE1rmSeriesProvider = FutureProvider.autoDispose
    .family<ExerciseE1rmSeries, String>((ref, exerciseId) async {
  return ref.read(progressRepositoryProvider).exerciseE1rmSeries(exerciseId);
});

/// Bodyweight trend for the home Body section (`/api/me/progress/metrics/series?type=weight`).
/// `autoDispose`: loads independently of the overview call so a slow/absent metrics endpoint never
/// blocks the page; the section degrades to an empty-state invite on no data and stays quiet on error.
final bodyweightSeriesProvider =
    FutureProvider.autoDispose<MetricSeries>((ref) async {
  return ref.read(progressRepositoryProvider).metricSeries('weight');
});

/// The trainee's current goal weight (Phase 3, Decision **D12**) — read as the latest point of the
/// `goal_weight` metric series. `autoDispose`: the Body section watches it to overlay the goal line +
/// distance-to-goal caption; null = no goal set yet → the section shows the "set a goal weight"
/// affordance. The set-goal sheet invalidates this provider so the new line shows immediately.
final goalWeightProvider = FutureProvider.autoDispose<double?>((ref) async {
  // A goal is a long-lived setting, not a 12-week series — read with a far-past `from` so the
  // current goal is found however long ago it was set (the default window would silently drop it).
  final series = await ref
      .read(progressRepositoryProvider)
      .metricSeries('goal_weight', from: DateTime(2000, 1, 1));
  // Latest-per-day, day-ascending → the last point is the current goal. Empty = no goal set.
  if (series.points.isEmpty) return null;
  return series.points.last.value;
});

/// Recent nutrition adherence for the home Body→nutrition card (Phase 3, Decision **D13**).
/// `autoDispose`: loads independently of everything above — a slow/absent endpoint never blocks the
/// glance layer; the card degrades to its "follow a meal plan" invite (`hasPlan: false`) and stays
/// quiet on loading/error.
final nutritionAdherenceProvider =
    FutureProvider.autoDispose<NutritionAdherence>((ref) async {
  return ref.read(progressRepositoryProvider).nutritionAdherence();
});
