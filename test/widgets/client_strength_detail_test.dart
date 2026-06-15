import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/coach_models.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/coach/client_strength_screen.dart';
import 'package:gymbroapp/features/coach/coach_providers.dart';
import 'package:gymbroapp/features/progress/trend_chart.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Phase-2b coach per-client strength detail (COACH-VS-TRAINEE.md §3). Overrides
/// [clientStrengthProvider] and [coachRosterProvider] so nothing touches the network. The load-bearing
/// rule: there is **no body-metric card** — the coach has no `MetricEntry` path for another user.
void main() {
  const clientId = 'c1';

  E1rmSeriesPoint point(double e1rm, {bool pr = false}) =>
      E1rmSeriesPoint(sessionBestE1rmKg: e1rm, isPr: pr);

  ExerciseE1rmSeries lift({
    String name = 'Barbell Bench Press',
    List<E1rmSeriesPoint> points = const [],
    double current = 100,
    LiftTrendDirection direction = LiftTrendDirection.up,
    bool stalled = false,
    int stallSessions = 0,
  }) =>
      ExerciseE1rmSeries(
        exerciseId: 'ex-$name',
        exerciseName: name,
        points: points,
        currentE1rmKg: current,
        deltaKgVsTrailing4w: 2,
        direction: direction,
        stalled: stalled,
        stallSessions: stallSessions,
      );

  ClientStatus status(RosterStatus s, {int done = 2, int? goal = 3}) => ClientStatus(
        traineeId: clientId,
        displayName: 'Alice',
        completedThisWeek: done,
        weeklyGoal: goal,
        status: s,
      );

  Widget host({
    required List<ExerciseE1rmSeries> lifts,
    Roster roster = const Roster(items: []),
    // The workload card loads its own provider; default to an empty-but-valid load so these
    // strength-focused tests don't touch the network (its own behavior is covered in workload_card_test).
    AcuteChronicLoad load = const AcuteChronicLoad(
      acuteVolumeKg: 0,
      chronicWeeklyVolumeKg: 0,
      trend: LoadTrend.steady,
    ),
  }) =>
      ProviderScope(
        overrides: [
          clientStrengthProvider.overrideWith((ref, id) async => lifts),
          coachRosterProvider.overrideWith((ref) async => roster),
          clientLoadProvider.overrideWith((ref, id) async => load),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ClientStrengthScreen(clientId: clientId, clientName: 'Alice'),
            ),
          ),
        ),
      );

  testWidgets('data → verdict header (name + status) and per-lift trend cards', (tester) async {
    await tester.pumpWidget(host(
      lifts: [
        lift(
          name: 'Barbell Bench Press',
          points: [point(90), point(92, pr: true), point(94), point(96, pr: true)],
          current: 96,
        ),
      ],
      roster: Roster(items: [status(RosterStatus.drifting)]),
    ));
    await tester.pumpAndSettle();

    // Header: name + the roster status chip carried through.
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Drifting'), findsOneWidget);

    // Strength section + the lift name + the shared trend chart.
    expect(find.text('Strength trends'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.byType(TrendChart), findsOneWidget);
    expect(find.text('Up'), findsOneWidget); // direction tag
  });

  testWidgets('NO body-metric card — weight/sleep tile is never rendered', (tester) async {
    await tester.pumpWidget(host(
      lifts: [
        lift(points: [point(90), point(92), point(94), point(96)]),
      ],
      roster: Roster(items: [status(RosterStatus.onTrack)]),
    ));
    await tester.pumpAndSettle();

    // The coach has no MetricEntry path — absence is the design (COACH-VS-TRAINEE.md §3). None of the
    // body-data affordances may appear on this screen.
    expect(find.text('Body data'), findsNothing);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('Sleep'), findsNothing);
    expect(find.byIcon(Icons.monitor_weight_outlined), findsNothing);
    expect(find.byIcon(Icons.bedtime_outlined), findsNothing);
  });

  testWidgets('multiple lifts → one trend card each', (tester) async {
    await tester.pumpWidget(host(
      lifts: [
        lift(name: 'Bench', points: [point(90), point(92), point(94), point(96)]),
        lift(name: 'Deadlift', points: [point(140), point(142), point(145), point(150)]),
      ],
      roster: Roster(items: [status(RosterStatus.onTrack)]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
    expect(find.byType(TrendChart), findsNWidgets(2));
  });

  testWidgets('empty strength → honest "No strength data yet", no chart', (tester) async {
    await tester.pumpWidget(host(
      lifts: const [],
      roster: Roster(items: [status(RosterStatus.quiet)]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No strength data yet'), findsOneWidget);
    expect(find.byType(TrendChart), findsNothing);
    // Still no body-metric card in the empty state either.
    expect(find.text('Body data'), findsNothing);
  });

  testWidgets('thin lift (<4 points) → trend card with the no-trend caption', (tester) async {
    await tester.pumpWidget(host(
      lifts: [
        lift(name: 'Squat', points: [point(100), point(102)]),
      ],
      roster: Roster(items: [status(RosterStatus.onTrack)]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.byType(TrendChart), findsOneWidget); // raw dots still drawn under the gate
    expect(find.textContaining('Not enough sessions in this gym'), findsOneWidget);
  });

  testWidgets('down lift → red "Slipping" tag is the only red', (tester) async {
    await tester.pumpWidget(host(
      lifts: [
        lift(
          name: 'OHP',
          points: [point(60), point(58), point(56), point(54)],
          direction: LiftTrendDirection.down,
        ),
      ],
      roster: Roster(items: [status(RosterStatus.drifting)]),
    ));
    await tester.pumpAndSettle();

    final gb = AppTheme.light().extension<GbColors>()!;
    // The DirTag now reads the design's honest neg channel (sparkColor → progNeg #AD3B32) — still the
    // only red on the coach surface, just the deeper design red rather than the old app danger.
    final tag = tester.widget<Text>(find.text('Slipping'));
    expect(tag.style?.color, gb.progNeg);
  });
}
