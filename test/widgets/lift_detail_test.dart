import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/lift_detail_screen.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
// widgets.dart re-exports the theme barrel, so this single import yields AppTheme,
// GbColors, EmptyState, ErrorRetry, GbSkeletonList, etc.
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Phase-2a per-lift drill-down (DRILL-DOWNS §1). Every test overrides
/// [exerciseE1rmSeriesProvider] (an `autoDispose.family`) so nothing touches the network. The
/// family is overridden with a function that branches on the `exerciseId` argument.
void main() {
  const exerciseId = 'ex-1';

  E1rmSeriesPoint point(double e1rm, {bool pr = false}) =>
      E1rmSeriesPoint(sessionBestE1rmKg: e1rm, isPr: pr);

  ExerciseE1rmSeries series({
    List<E1rmSeriesPoint> points = const [],
    String? name = 'Barbell Bench Press',
    double current = 100,
    double delta = 2.4,
    LiftTrendDirection direction = LiftTrendDirection.up,
    bool stalled = false,
    int stallSessions = 0,
  }) =>
      ExerciseE1rmSeries(
        exerciseId: exerciseId,
        exerciseName: name,
        points: points,
        currentE1rmKg: current,
        deltaKgVsTrailing4w: delta,
        direction: direction,
        stalled: stalled,
        stallSessions: stallSessions,
      );

  Widget host(Override override) => ProviderScope(
        overrides: [override],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const LiftDetailScreen(exerciseId: exerciseId),
            ),
          ),
        ),
      );

  Future<void> pumpData(WidgetTester tester, ExerciseE1rmSeries data) async {
    await tester.pumpWidget(
      host(exerciseE1rmSeriesProvider.overrideWith((ref, id) async => data)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loading → GbSkeletonList, no error', (tester) async {
    final completer = Completer<ExerciseE1rmSeries>();
    await tester.pumpWidget(
      host(exerciseE1rmSeriesProvider
          .overrideWith((ref, id) => completer.future)),
    );
    await tester.pump(); // one frame — the future never resolves yet

    expect(find.byType(GbSkeletonList), findsOneWidget);
    expect(find.byType(ErrorRetry), findsNothing);

    completer.complete(series());
    await tester.pumpAndSettle();
  });

  testWidgets('error → ErrorRetry with a Retry action', (tester) async {
    await tester.pumpWidget(
      host(exerciseE1rmSeriesProvider
          .overrideWith((ref, id) async => throw Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(GbSkeletonList), findsNothing);
  });

  testWidgets('empty points → "Not enough data yet" empty state', (tester) async {
    await pumpData(tester, series(points: const []));

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Not enough data yet'), findsOneWidget);
    // The header still shows a back affordance, never an error.
    expect(find.byType(ErrorRetry), findsNothing);
  });

  testWidgets('thin data (<4 points) → no trend line, "log N more" copy', (tester) async {
    await pumpData(
      tester,
      series(points: [point(90), point(92), point(94)]),
    );

    // The trend card renders, but with the gate copy (3 points → 1 more).
    expect(find.text('e1RM trend'), findsOneWidget);
    expect(find.textContaining('to see your trend'), findsOneWidget);
  });

  testWidgets('full data → trend card, header strip, direction tag', (tester) async {
    await pumpData(
      tester,
      series(
        points: [point(90), point(92, pr: true), point(94), point(96, pr: true)],
        current: 96,
        direction: LiftTrendDirection.up,
      ),
    );

    // Header strip: current e1RM number + unit + delta caption.
    expect(find.text('Current e1RM'.toUpperCase()), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(find.textContaining('vs your trailing 4 weeks'), findsOneWidget);

    // Trend card + legend (PR swatch present once it's a real trend).
    expect(find.text('e1RM trend'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget);
    // The up direction tag.
    expect(find.text('Up'), findsOneWidget);
  });

  testWidgets('PR markers are painted (CustomPaint present for the trend)', (tester) async {
    // We can't read pixels, but the trend chart's CustomPaint must be mounted for a ≥4-point series
    // that carries PR points. Assert the chart surface and PR legend swatch both render.
    await pumpData(
      tester,
      series(
        points: [point(90), point(92), point(95, pr: true), point(98, pr: true)],
        direction: LiftTrendDirection.up,
      ),
    );

    // At least one CustomPaint inside the trend card (the painter draws the line + PR dots).
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('e1RM trend'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget); // PR legend → markers are drawn
  });

  testWidgets('down direction → red "Slipping" tag is the only red', (tester) async {
    await pumpData(
      tester,
      series(
        points: [point(96), point(94), point(92), point(90)],
        direction: LiftTrendDirection.down,
        delta: -3.0,
      ),
    );

    final gb = AppTheme.light().extension<GbColors>()!;
    // The DirTag now reads the design's honest neg channel (sparkColor → progNeg #AD3B32) — still the
    // only red on the surface, just the deeper design red rather than the old app danger.
    final tag = tester.widget<Text>(find.text('Slipping'));
    expect(tag.style?.color, gb.progNeg);

    // The delta caption is neutral copy ("−3 kg …"), never red.
    final caption = tester.widget<Text>(
        find.textContaining('vs your trailing 4 weeks'));
    expect(caption.style?.color, isNot(gb.progNeg));
    expect(caption.style?.color, isNot(gb.danger));
  });

  testWidgets('stalled flat lift → "Flat N×" tag + neutral stall note', (tester) async {
    await pumpData(
      tester,
      series(
        points: [point(100), point(100), point(101), point(100)],
        direction: LiftTrendDirection.flat,
        stalled: true,
        stallSessions: 4,
        delta: 0,
      ),
    );

    final gb = AppTheme.light().extension<GbColors>()!;
    // Flat now reads the design's warn-amber DirTag (sparkColor → progWarn #8A6312), not neutral grey —
    // an attention tone, still never red.
    final tag = tester.widget<Text>(find.text('Flat 4×'));
    expect(tag.style?.color, gb.progWarn);
    expect(tag.style?.color, isNot(gb.danger));

    // The stall callout renders, framed as an observation (never red).
    expect(find.textContaining('Flat for 4 sessions'), findsOneWidget);
    expect(find.textContaining('No change'), findsOneWidget); // delta caption
  });
}
