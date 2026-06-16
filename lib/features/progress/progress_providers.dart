import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/progress_models.dart';
import '../../data/repositories/progress_repository.dart';

/// The Progress page's view mode: a **Today** snapshot+advice dashboard, or one of three trend windows.
enum ProgressRange { today, week, fourWeek, twelveWeek }

extension ProgressRangeX on ProgressRange {
  /// Trend look-back in weeks. Today renders the snapshot (not trends), so it just reuses the 12w
  /// window under the hood for any provider that still happens to read the weeks value.
  int get weeks => switch (this) {
        ProgressRange.today => 12,
        ProgressRange.week => 1,
        ProgressRange.fourWeek => 4,
        ProgressRange.twelveWeek => 12,
      };

  String get label => switch (this) {
        ProgressRange.today => 'Today',
        ProgressRange.week => 'Week',
        ProgressRange.fourWeek => '4w',
        ProgressRange.twelveWeek => '12w',
      };
}

/// The selected Progress view. Default = **12 weeks** — the page lands on the trend glance it always
/// has, with **Today** (the snapshot+advice dashboard) sitting as the prominent first tab one tap away.
/// Page-level state (a plain [StateProvider]), NOT `autoDispose` — the choice survives a tab switch /
/// drill-down round-trip so the control reads as a persistent page setting, not a per-visit reset.
final progressRangeProvider =
    StateProvider<ProgressRange>((ref) => ProgressRange.twelveWeek);

/// The selected look-back window in weeks, derived from [progressRangeProvider]. The overview +
/// per-lift e1RM + strength + nutrition fetches read it and re-request with the matching window. The
/// This Week hero is intentionally NOT period-sensitive — it always reflects the current week.
final progressPeriodWeeksProvider =
    Provider<int>((ref) => ref.watch(progressRangeProvider).weeks);

/// The trainee Progress home — one self-scoped read (`GET /api/me/progress/overview?weeks=N`).
///
/// `autoDispose`: the tab refetches naturally on re-entry (cheap, uncached, always fresh — PHASE-1
/// §4/§6). Pull-to-refresh invalidates this provider and awaits its future. Watches
/// [progressPeriodWeeksProvider] so changing the period re-requests the overview with the new window.
final progressOverviewProvider =
    FutureProvider.autoDispose<ProgressOverview>((ref) async {
  final weeks = ref.watch(progressPeriodWeeksProvider);
  return ref.read(progressRepositoryProvider).overview(weeks: weeks);
});

/// Per-lift e1RM series for the strength drill-down (`/api/me/exercises/{id}/e1rm-series`), keyed by
/// exercise id. `autoDispose.family`: each lift detail is fetched on open and dropped on close —
/// fresh every visit, like the overview. The drill-down screen renders loading/error/empty/data.
///
/// Watches [progressPeriodWeeksProvider] and threads it into the request as `from = today − N weeks`
/// / `to = today`, so the drill-down trend honours the same period the home page is showing. The
/// family key stays the exercise id alone (the window rides the watched provider), so a period change
/// re-fetches every open lift series.
final exerciseE1rmSeriesProvider = FutureProvider.autoDispose
    .family<ExerciseE1rmSeries, String>((ref, exerciseId) async {
  final weeks = ref.watch(progressPeriodWeeksProvider);
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day);
  final from = to.subtract(Duration(days: 7 * weeks));
  return ref
      .read(progressRepositoryProvider)
      .exerciseE1rmSeries(exerciseId, from: from, to: to);
});

/// Every performed lift over the selected period (`/api/me/exercises/strength-lifts?weeks=N`), behind
/// the Strength section's muscle-group chip row + all-exercises picker. `autoDispose`: fetched on tab
/// entry like the overview, fresh every visit. Watches [progressPeriodWeeksProvider] so changing the
/// period re-requests the lift list with the new window — keeping it aligned with the top-3 glance
/// strip the overview powers. The muscle filter is applied client-side off this one list (so switching
/// chips needs no refetch); the chip set itself is derived from the non-null `primaryMuscleGroup`
/// values present here, so a dead/untrained group never renders a chip.
final strengthLiftsProvider =
    FutureProvider.autoDispose<StrengthLifts>((ref) async {
  final weeks = ref.watch(progressPeriodWeeksProvider);
  return ref.read(progressRepositoryProvider).strengthLifts(weeks: weeks);
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
/// quiet on loading/error. Watches [progressPeriodWeeksProvider] and passes the selected window
/// (`from = today − N weeks` / `to = today`) so the calories trend matches the chosen period — the
/// endpoint accepts `?from=&to=` (default trailing 4 weeks).
final nutritionAdherenceProvider =
    FutureProvider.autoDispose<NutritionAdherence>((ref) async {
  final weeks = ref.watch(progressPeriodWeeksProvider);
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day);
  final from = to.subtract(Duration(days: 7 * weeks));
  return ref
      .read(progressRepositoryProvider)
      .nutritionAdherence(from: from, to: to);
});
