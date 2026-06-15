import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/lift_widgets.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the genuinely-new visual elements introduced by the "Graphite / premium-blue"
/// restyle of the trainee Progress home: the dark "This week" hero panel (gradient + ring + mono
/// labels), the strength stall callout row, and the DirTag's caret glyph. These guard the new
/// composition renders cleanly (no layout/paint exceptions) and that the honesty-gated stall row only
/// appears for a genuinely-stalled lift. Data/state wiring itself is covered by progress_screen_test.
void main() {
  WeekAdherence week({
    int completed = 0,
    int? goal,
    bool hasPlan = false,
    DateTime? start,
  }) =>
      WeekAdherence(
        weekStart: start,
        completedSessions: completed,
        goal: goal,
        hasActivePlan: hasPlan,
      );

  LiftDirection lift({
    required LiftTrendDirection direction,
    bool stalled = false,
    int stallSessions = 0,
    List<double> spark = const [90, 92, 94, 96, 98],
  }) =>
      LiftDirection(
        exerciseId: 'e1',
        exerciseName: 'Squat',
        currentE1rmKg: 130,
        direction: direction,
        stalled: stalled,
        stallSessions: stallSessions,
        sparkE1rmKg: spark,
      );

  ProgressOverview overview({
    WeekAdherence? thisWeek,
    List<LiftDirection> lifts = const [],
    List<PersonalRecord> prs = const [],
  }) =>
      ProgressOverview(
        thisWeek: thisWeek ?? week(),
        consistency:
            const Consistency(windowWeeks: 12, days: [], currentStreakWeeks: 0),
        topLifts: lifts,
        recentPrs: prs,
      );

  Future<void> pumpData(WidgetTester tester, ProgressOverview data) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressOverviewProvider.overrideWith((ref) async => data),
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

  testWidgets('planned week → dark hero panel: gradient + ring + mono labels', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(
            completed: 3, goal: 4, hasPlan: true, start: DateTime.now()),
        prs: [
          const PersonalRecord(
            exerciseId: 'p1',
            exerciseName: 'Deadlift',
            weightKg: 140,
            reps: 3,
            estimatedOneRepMaxKg: 153,
          ),
        ],
      ),
    );

    // The hero renders the mono "THIS WEEK" eyebrow and the adherence ring with the "3/4" center.
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.byType(GbRing), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    // The right-of-ring lead line and the days-left mono caption render.
    expect(find.text('1 session to your goal'), findsOneWidget);
    expect(find.textContaining('REST DAYS COUNT'), findsOneWidget);

    // The hero panel is a navy gradient container — assert a DecoratedBox carries the gradient.
    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((b) => b.gradient)
        .whereType<LinearGradient>()
        .toList();
    expect(gradients, contains(GbColors.progressHeroGradient));
  });

  testWidgets('stalled flat top lift → amber stall callout row renders', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        lifts: [
          lift(
            direction: LiftTrendDirection.flat,
            stalled: true,
            stallSessions: 4,
          ),
        ],
      ),
    );

    // The honesty-gated stall callout appears with the warn-amber closing fragment.
    expect(find.textContaining("hasn't moved in 4 sessions"), findsOneWidget);
    expect(find.textContaining('time to change something'), findsOneWidget);
  });

  testWidgets('non-stalled top lifts → no stall callout row', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 2, hasPlan: false),
        lifts: [lift(direction: LiftTrendDirection.up)],
      ),
    );

    expect(find.textContaining('time to change something'), findsNothing);
  });

  testWidgets('DirTag paints a caret glyph (CustomPaint) beside the label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: LiftDirectionTag(
              direction: LiftTrendDirection.up,
              stalled: false,
              stallSessions: 0,
            ),
          ),
        ),
      ),
    );

    // The caret is a CustomPaint, and the mono label reads "Up".
    expect(find.descendant(
        of: find.byType(LiftDirectionTag), matching: find.byType(CustomPaint)),
        findsOneWidget);
    expect(find.text('Up'), findsOneWidget);
  });
}
