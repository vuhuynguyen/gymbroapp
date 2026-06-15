import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/data/repositories/progress_repository.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the conditional Section-5 Body block on the trainee Progress home
/// (MOBILE-DASHBOARD §5), now goal-aware (Phase 3). The block is private, so we drive it through
/// [ProgressScreen]: we override [progressOverviewProvider] with a non-new-user overview (so the data
/// ListView renders, not the hero), [bodyweightSeriesProvider] with the body fixture under test, and
/// [goalWeightProvider] with the goal under test (null = no goal set).
void main() {
  // A non-empty overview that is NOT the new-user hero (it has a PR), so §1–5 render.
  ProgressOverview nonEmptyOverview() => const ProgressOverview(
        thisWeek: WeekAdherence(completedSessions: 2, hasActivePlan: false),
        consistency:
            Consistency(windowWeeks: 12, days: [], currentStreakWeeks: 0),
        topLifts: [],
        recentPrs: [
          PersonalRecord(
            exerciseId: 'p1',
            exerciseName: 'Deadlift',
            weightKg: 140,
            reps: 3,
            estimatedOneRepMaxKg: 153,
          ),
        ],
      );

  MetricSeries weight(List<double> values) => MetricSeries(
        type: 'weight',
        unit: 'kg',
        points: [for (final v in values) MetricSeriesPoint(value: v)],
      );

  Future<void> pump(
    WidgetTester tester,
    AsyncValue<MetricSeries> body, {
    double? goalKg,
    ProgressRepository? repo,
    bool overrideGoal = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressOverviewProvider
              .overrideWith((ref) async => nonEmptyOverview()),
          // Resolve the body provider to the supplied async state.
          bodyweightSeriesProvider.overrideWith((ref) async {
            return body.when(
              data: (d) => d,
              loading: () => throw StateError('use a resolved value'),
              error: (e, _) => throw e,
            );
          }),
          // Goal weight: null unless the test supplies one. The write test lets the real provider run
          // against the fake repo (so invalidate → refetch is observable), so it opts out here.
          if (overrideGoal)
            goalWeightProvider.overrideWith((ref) async => goalKg),
          // Nutrition card is quiet (no plan) unless a test cares; keeps the page tidy.
          nutritionAdherenceProvider.overrideWith(
              (ref) async => const NutritionAdherence(hasPlan: false, recentDays: [])),
          if (repo != null) progressRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ProgressScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scroll the lazy ListView until [finder] is built + visible (Body/Nutrition sit below the fold).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }

  testWidgets('no weigh-ins → empty-state invite, no chart', (tester) async {
    await pump(tester, AsyncData(weight(const [])));
    await scrollTo(tester, find.text('BODY'));

    expect(find.text('BODY'), findsOneWidget); // section title renders
    expect(find.text('Log your weight to see your trend.'), findsOneWidget);
    // No "Bodyweight" card eyebrow when empty.
    expect(find.text('Bodyweight'.toUpperCase()), findsNothing);
  });

  testWidgets('weigh-ins present → trend card with the Bodyweight eyebrow', (tester) async {
    await pump(
      tester,
      AsyncData(weight(const [80.2, 80.0, 79.6, 79.8, 79.4])),
    );
    await scrollTo(tester, find.text('BODY'));

    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('Bodyweight'.toUpperCase()), findsOneWidget);
    // The invite copy must NOT show when there's data.
    expect(find.text('Log your weight to see your trend.'), findsNothing);
    // A CustomPaint chart surface is mounted (the EMA trend painter).
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('body provider errors → section stays quiet, page unblocked', (tester) async {
    // The Body block collapses to nothing on error; the rest of the page still renders.
    await pump(tester, AsyncError(Exception('metrics down'), StackTrace.empty));

    // The page (other sections) is unaffected — the PR teaser still renders.
    await scrollTo(tester, find.text('PERSONAL RECORDS'));
    expect(find.text('PERSONAL RECORDS'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
    // The Body section neither errors the page nor shows the invite.
    expect(find.byType(ErrorRetry), findsNothing);
    expect(find.text('BODY'), findsNothing);
    expect(find.text('Log your weight to see your trend.'), findsNothing);
  });

  // ── Phase 3 — goal-aware Body section ─────────────────────────────────────

  testWidgets('no goal weight → "Set a goal weight" affordance, no distance caption',
      (tester) async {
    await pump(
      tester,
      AsyncData(weight(const [80.2, 80.0, 79.6, 79.8])),
      goalKg: null,
    );
    await scrollTo(tester, find.text('Set a goal weight'));

    // The set-goal affordance is offered; no goal chip / distance caption.
    expect(find.text('Set a goal weight'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
    expect(find.textContaining('Goal '), findsNothing);
  });

  testWidgets('goal weight set → goal chip + distance-to-goal caption, no affordance',
      (tester) async {
    // Latest weigh-in 78.2, goal 75 → 3.2 kg to go.
    await pump(
      tester,
      AsyncData(weight(const [80.2, 80.0, 79.0, 78.2])),
      goalKg: 75.0,
    );
    await scrollTo(tester, find.text('3.2 kg to go'));

    // The goal chip reads "Goal 75 kg" and the caption the remaining distance.
    expect(find.text('Goal 75 kg'), findsOneWidget);
    expect(find.text('3.2 kg to go'), findsOneWidget);
    // The "set a goal" affordance is replaced once a goal exists.
    expect(find.text('Set a goal weight'), findsNothing);
  });

  testWidgets('at goal weight → "At your goal weight" caption', (tester) async {
    await pump(
      tester,
      AsyncData(weight(const [76.0, 75.4, 75.0])),
      goalKg: 75.0,
    );
    await scrollTo(tester, find.text('At your goal weight'));

    expect(find.text('At your goal weight'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
  });

  testWidgets('set-goal sheet writes goal_weight and invalidates the goal provider',
      (tester) async {
    final repo = _FakeProgressRepository();
    await pump(
      tester,
      AsyncData(weight(const [80.0, 79.5, 79.0, 78.5])),
      // Let the real goalWeightProvider run against the fake repo so the invalidate → refetch is
      // observable via repo.goalReads (rather than masking it behind a static override).
      overrideGoal: false,
      repo: repo,
    );

    // Open the sheet from the affordance. Scroll the page fully to the bottom first so the affordance
    // sits comfortably above the fold (scrollUntilVisible alone can leave it pinned at the very edge,
    // where the tap offset misses the hit box). Scrolling here also mounts the Body card — which now
    // sits below the new period bar — so the real goalWeightProvider subscribes + reads before we
    // snapshot the count below.
    final affordance = find.text('Set a goal weight');
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(affordance, 300, scrollable: scrollable);
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(affordance);
    await tester.pumpAndSettle();

    // The real provider read the (empty) goal_weight series once the Body card mounted.
    final readsBeforeWrite = repo.goalReads;
    expect(readsBeforeWrite, greaterThanOrEqualTo(1));

    await tester.tap(affordance);
    await tester.pumpAndSettle();
    expect(find.text('Save goal'), findsOneWidget);

    // Type a goal and save.
    await tester.enterText(find.byType(TextField), '72.5');
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    // The write hit the repo with the parsed kg…
    expect(repo.savedGoals, [72.5]);
    // …the goal provider was invalidated, so it refetched (one more goal_weight read)…
    expect(repo.goalReads, greaterThan(readsBeforeWrite));
    // …and the sheet dismissed.
    expect(find.text('Save goal'), findsNothing);
  });
}

/// A fake repository that records goal-weight writes and counts goal reads — no Dio, no network.
class _FakeProgressRepository implements ProgressRepository {
  final List<double> savedGoals = [];
  int goalReads = 0;

  @override
  Future<void> setGoalWeight(double kg) async => savedGoals.add(kg);

  @override
  Future<MetricSeries> metricSeries(String type, {DateTime? from}) async {
    if (type == 'goal_weight') goalReads++;
    return MetricSeries(type: type, unit: 'kg', points: const []);
  }

  // The screen only invalidates goalWeightProvider (which goes through the overridden provider in the
  // test, not this method) — but implement the rest of the surface defensively.
  @override
  Future<ProgressOverview> overview({int? weeks}) async =>
      ProgressOverview.fromJson(const {});

  @override
  Future<ExerciseE1rmSeries> exerciseE1rmSeries(
    String exerciseId, {
    DateTime? from,
    DateTime? to,
  }) async =>
      ExerciseE1rmSeries.fromJson({'exerciseId': exerciseId});

  @override
  Future<NutritionAdherence> nutritionAdherence({
    DateTime? from,
    DateTime? to,
  }) async =>
      NutritionAdherence.fromJson(const {});
}
