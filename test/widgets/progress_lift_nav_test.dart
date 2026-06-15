import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/lift_detail_screen.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Tapping a home Strength row navigates to that lift's drill-down (`/progress/lift/:exerciseId`).
/// Uses a minimal real [GoRouter] with just the two routes (not the app router, to avoid its auth
/// redirect/shell), and overrides the providers so nothing touches the network.
void main() {
  const liftId = 'ex-42';

  testWidgets('tapping a strength lift row pushes the per-lift drill-down', (tester) async {
    const overview = ProgressOverview(
      thisWeek: WeekAdherence(completedSessions: 2, hasActivePlan: false),
      consistency:
          Consistency(windowWeeks: 12, days: [], currentStreakWeeks: 0),
      topLifts: [
        LiftDirection(
          exerciseId: liftId,
          exerciseName: 'Barbell Bench Press',
          currentE1rmKg: 96,
          direction: LiftTrendDirection.up,
          stalled: false,
          stallSessions: 0,
          sparkE1rmKg: [90, 92, 94, 96],
        ),
      ],
      recentPrs: [],
    );

    const detail = ExerciseE1rmSeries(
      exerciseId: liftId,
      exerciseName: 'Barbell Bench Press',
      points: [
        E1rmSeriesPoint(sessionBestE1rmKg: 90, isPr: true),
        E1rmSeriesPoint(sessionBestE1rmKg: 92, isPr: false),
        E1rmSeriesPoint(sessionBestE1rmKg: 94, isPr: false),
        E1rmSeriesPoint(sessionBestE1rmKg: 96, isPr: true),
      ],
      currentE1rmKg: 96,
      deltaKgVsTrailing4w: 2.4,
      direction: LiftTrendDirection.up,
      stalled: false,
      stallSessions: 0,
    );

    final router = GoRouter(
      initialLocation: '/progress',
      routes: [
        GoRoute(
            path: '/progress', builder: (_, __) => const ProgressScreen()),
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
          progressOverviewProvider.overrideWith((ref) async => overview),
          exerciseE1rmSeriesProvider
              .overrideWith((ref, id) async => detail),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The home strength strip shows the lift; the detail screen is not yet on screen. (The Graphite
    // SectionTitle renders its label uppercased + tracked.)
    expect(find.text('STRENGTH'), findsOneWidget);
    expect(find.byType(LiftDetailScreen), findsNothing);
    // "Barbell Bench Press" appears once (the home row); the detail header restates it after nav.
    expect(find.text('Barbell Bench Press'), findsOneWidget);

    // Tap the lift row (its title) and let the route push.
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    // We're on the drill-down: the e1RM trend card + the detail-screen widget are present.
    expect(find.byType(LiftDetailScreen), findsOneWidget);
    expect(find.text('e1RM trend'), findsOneWidget);
    expect(find.text('Current e1RM'.toUpperCase()), findsOneWidget);
  });
}
