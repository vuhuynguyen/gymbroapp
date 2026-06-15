import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/lift_detail_screen.dart';
import 'package:gymbroapp/features/progress/lift_widgets.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Strength section's muscle-group + exercise filtering (the new feature):
///   • the chip row renders ONLY the trained groups ("All" + chips, never a dead chip);
///   • selecting a muscle chip filters the rows to that group;
///   • a hasTrend=false lift shows e1RM + "N sessions" with NO direction tag (no fabricated trend);
///   • the all-exercises picker opens and routes to the EXISTING per-lift drill-down.
///
/// Everything is overridden off-network: the overview drives the "All" glance strip, and
/// `strengthLiftsProvider` drives the chips / filtered rows / picker. The Body/Nutrition sections are
/// stubbed to their quiet empty-states so the page never fires a real Dio call as it scrolls.
void main() {
  // ── Fixtures ────────────────────────────────────────────────────────────────

  StrengthLift sl({
    required String id,
    required String name,
    String? muscle,
    double e1rm = 100,
    int sessions = 5,
    bool hasTrend = true,
    LiftTrendDirection direction = LiftTrendDirection.up,
    List<double> spark = const [90, 92, 94, 96],
  }) =>
      StrengthLift(
        exerciseId: id,
        exerciseName: name,
        primaryMuscleGroup: muscle,
        sessionCount: sessions,
        currentE1rmKg: e1rm,
        hasTrend: hasTrend,
        direction: direction,
        stalled: false,
        stallSessions: 0,
        sparkE1rmKg: hasTrend ? spark : const [],
      );

  // A minimal non-empty overview so the page renders the data layout (not the new-user hero), with the
  // "All" glance strip driven by these top lifts.
  ProgressOverview overview({List<LiftDirection> topLifts = const []}) =>
      ProgressOverview(
        thisWeek: const WeekAdherence(completedSessions: 2, hasActivePlan: false),
        consistency:
            const Consistency(windowWeeks: 12, days: [], currentStreakWeeks: 0),
        topLifts: topLifts,
        recentPrs: const [],
      );

  const benchTop = LiftDirection(
    exerciseId: 'bench',
    exerciseName: 'Barbell Bench Press',
    currentE1rmKg: 96,
    direction: LiftTrendDirection.up,
    stalled: false,
    stallSessions: 0,
    sparkE1rmKg: [90, 92, 94, 96],
  );

  /// Pumps [ProgressScreen] inside a real (minimal) GoRouter with the lift drill-down route, so a
  /// picker tap can actually push `/progress/lift/:id`. The strength + section providers are overridden
  /// off-network.
  Future<void> pump(
    WidgetTester tester, {
    required ProgressOverview ov,
    required List<StrengthLift> lifts,
    ExerciseE1rmSeries? detail,
  }) async {
    final router = GoRouter(
      initialLocation: '/progress',
      routes: [
        GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
        GoRoute(
          path: '/progress/lift/:exerciseId',
          builder: (_, s) =>
              LiftDetailScreen(exerciseId: s.pathParameters['exerciseId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressOverviewProvider.overrideWith((ref) async => ov),
          strengthLiftsProvider
              .overrideWith((ref) async => StrengthLifts(lifts: lifts)),
          // Off-network conditional sections.
          bodyweightSeriesProvider.overrideWith(
              (ref) async => const MetricSeries(type: 'weight', points: [])),
          goalWeightProvider.overrideWith((ref) async => null),
          nutritionAdherenceProvider.overrideWith((ref) async =>
              const NutritionAdherence(hasPlan: false, recentDays: [])),
          if (detail != null)
            exerciseE1rmSeriesProvider.overrideWith((ref, id) async => detail),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ── Tests ─────────────────────────────────────────────────────────────────

  testWidgets('chip row shows "All" + ONLY the trained muscle groups (no dead chip)',
      (tester) async {
    await pump(
      tester,
      ov: overview(topLifts: const [benchTop]),
      lifts: [
        sl(id: 'bench', name: 'Bench Press', muscle: 'chest', e1rm: 96),
        sl(id: 'row', name: 'Barbell Row', muscle: 'back', e1rm: 110),
        // A null/unresolved group must NOT produce a chip.
        sl(id: 'mystery', name: 'Mystery Lift', muscle: null, e1rm: 40),
      ],
    );

    // "All" is always present; trained groups (chest, back) each get a chip.
    expect(find.text('All'), findsOneWidget, reason: '"All" chip always renders');
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    // Untrained groups (legs/shoulders/arms/core) and the null-group lift render NO chip.
    expect(find.text('Legs'), findsNothing);
    expect(find.text('Shoulders'), findsNothing);
    expect(find.text('Arms'), findsNothing);
    expect(find.text('Core'), findsNothing);
  });

  testWidgets('selecting a muscle chip filters the rows to that group', (tester) async {
    await pump(
      tester,
      ov: overview(topLifts: const [benchTop]),
      lifts: [
        sl(id: 'bench', name: 'Bench Press', muscle: 'chest', e1rm: 96),
        sl(id: 'fly', name: 'Cable Fly', muscle: 'chest', e1rm: 40),
        sl(id: 'row', name: 'Barbell Row', muscle: 'back', e1rm: 110),
      ],
    );

    // "All" → the glance strip shows the overview's top lift (Bench Press), not the back lift.
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Row'), findsNothing);

    // Tap the "Back" chip → only the back lift's row shows; the chest lifts are filtered out.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    expect(find.text('Cable Fly'), findsNothing);

    // Switch to "Chest" → both chest lifts show, the back lift is gone.
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Fly'), findsOneWidget);
    expect(find.text('Barbell Row'), findsNothing);
  });

  testWidgets('a hasTrend=false lift shows e1RM + "N sessions" and NO direction tag',
      (tester) async {
    await pump(
      tester,
      ov: overview(topLifts: const [benchTop]),
      lifts: [
        // A thin chest lift: not enough sessions for a trend.
        sl(
          id: 'incline',
          name: 'Incline Press',
          muscle: 'chest',
          e1rm: 72,
          sessions: 2,
          hasTrend: false,
        ),
      ],
    );

    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();

    // The row renders the lift + its current e1RM + the honest "2 sessions" caption (the mono caption
    // label is rendered uppercased by the design's _MonoLabel).
    expect(find.text('Incline Press'), findsOneWidget);
    expect(find.textContaining('72'), findsWidgets); // the e1RM value
    expect(find.text('2 SESSIONS'), findsOneWidget);

    // NO fabricated trend: no direction tag and no sparkline for the thin lift.
    expect(find.byType(LiftDirectionTag), findsNothing,
        reason: 'a thin lift never shows a direction tag');
  });

  testWidgets('the all-exercises picker opens and routes to the lift drill-down',
      (tester) async {
    const detail = ExerciseE1rmSeries(
      exerciseId: 'row',
      exerciseName: 'Barbell Row',
      points: [
        E1rmSeriesPoint(sessionBestE1rmKg: 104, isPr: true),
        E1rmSeriesPoint(sessionBestE1rmKg: 106, isPr: false),
        E1rmSeriesPoint(sessionBestE1rmKg: 108, isPr: false),
        E1rmSeriesPoint(sessionBestE1rmKg: 110, isPr: true),
      ],
      currentE1rmKg: 110,
      deltaKgVsTrailing4w: 4,
      direction: LiftTrendDirection.up,
      stalled: false,
      stallSessions: 0,
    );

    await pump(
      tester,
      ov: overview(topLifts: const [benchTop]),
      lifts: [
        sl(id: 'bench', name: 'Bench Press', muscle: 'chest', e1rm: 96),
        sl(id: 'row', name: 'Barbell Row', muscle: 'back', e1rm: 110),
      ],
      detail: detail,
    );

    // The picker is closed; the detail screen is not on screen yet.
    expect(find.byType(LiftDetailScreen), findsNothing);

    // Open the picker via the Strength header's "All exercises" action.
    await tester.tap(find.text('All exercises'));
    await tester.pumpAndSettle();

    // The picker sheet is up — its header + a grouped row are visible.
    expect(find.text('Tap a lift to see its trend.'), findsOneWidget);
    expect(find.text('Barbell Row'), findsWidgets);

    // Tapping a lift pops the sheet and routes to the EXISTING per-lift drill-down.
    await tester.tap(find.text('Barbell Row').last);
    await tester.pumpAndSettle();

    expect(find.byType(LiftDetailScreen), findsOneWidget);
    expect(find.text('e1RM trend'), findsOneWidget);
  });
}
