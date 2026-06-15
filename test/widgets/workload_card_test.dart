import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/coach_models.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/coach/client_strength_screen.dart';
import 'package:gymbroapp/features/coach/coach_providers.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Phase-4 coach **workload (acute-vs-chronic) card** on the per-client detail
/// (Decision D14 / COACH-VS-TRAINEE.md §3). Everything is mocked — [clientLoadProvider],
/// [clientStrengthProvider] and [coachRosterProvider] are overridden so nothing touches the network.
///
/// Load-bearing rules under test:
///  - **Two SEPARATE bars** (acute 7-day + chronic weekly-average), labeled with kg — **never a ratio**.
///  - The **soft** trend chip maps detraining/steady/ramping → "Easing off" / "Steady" / "Ramping up",
///    in a gentle (never red-alarm) tone, with no medical claim.
///  - A short caption "7-day vs 4-week weekly average · this gym only".
///  - Empty/zero → a quiet card (not two empty bars + a misleading "steady"); loading → skeleton;
///    error → quiet (NO `ErrorRetry`) so it never blocks the strength trends above.
void main() {
  const clientId = 'c1';

  // A single qualifying lift so the strength section renders and we can prove the workload card sits
  // below it without disturbing it.
  const lifts = <ExerciseE1rmSeries>[
    ExerciseE1rmSeries(
      exerciseId: 'ex-bench',
      exerciseName: 'Bench',
      points: [
        E1rmSeriesPoint(sessionBestE1rmKg: 90, isPr: false),
        E1rmSeriesPoint(sessionBestE1rmKg: 92, isPr: true),
        E1rmSeriesPoint(sessionBestE1rmKg: 94, isPr: false),
        E1rmSeriesPoint(sessionBestE1rmKg: 96, isPr: true),
      ],
      currentE1rmKg: 96,
      deltaKgVsTrailing4w: 2,
      direction: LiftTrendDirection.up,
      stalled: false,
      stallSessions: 0,
    ),
  ];

  /// Host the screen with the workload provider in a fixed [AsyncValue] state (data/loading/error).
  Widget host(AsyncValue<AcuteChronicLoad> loadState) => ProviderScope(
        overrides: [
          clientStrengthProvider.overrideWith((ref, id) async => lifts),
          coachRosterProvider.overrideWith((ref) async => const Roster(items: [])),
          clientLoadProvider.overrideWith((ref, id) => switch (loadState) {
                AsyncData(:final value) => Future.value(value),
                AsyncError(:final error) => Future<AcuteChronicLoad>.error(error),
                // loading: a future that never completes within the test pump window.
                _ => Future<AcuteChronicLoad>.delayed(const Duration(seconds: 30)),
              }),
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

  Widget hostData(AcuteChronicLoad load) => host(AsyncData(load));

  testWidgets('data → two separate bars with kg labels + the scope caption (no ratio)', (tester) async {
    await tester.pumpWidget(hostData(const AcuteChronicLoad(
      acuteVolumeKg: 12000,
      chronicWeeklyVolumeKg: 9000,
      trend: LoadTrend.ramping,
    )));
    await tester.pumpAndSettle();

    // The section + both bars (each names its window and shows its own kg value).
    expect(find.text('Workload'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('last 7 days'), findsOneWidget);
    expect(find.text('Weekly average'), findsOneWidget);
    expect(find.text('last 4 weeks'), findsOneWidget);

    // Two distinct kg values — the two bars are separate, not a single combined number.
    expect(find.text('12000 kg'), findsOneWidget);
    expect(find.text('9000 kg'), findsOneWidget);

    // Mandatory caption.
    expect(find.text('7-day vs 4-week weekly average · this gym only'), findsOneWidget);

    // NO ratio anywhere — never an ACWR number / "x" multiplier on this card.
    expect(find.textContaining('ratio', findRichText: true), findsNothing);
    expect(find.textContaining('ACWR', findRichText: true), findsNothing);
    expect(find.textContaining('1.3', findRichText: true), findsNothing);

    // The strength trends still render above the workload card (workload never disturbs them).
    expect(find.text('Strength trends'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
  });

  testWidgets('trend chip mapping: ramping → "Ramping up" (amber, not red)', (tester) async {
    await tester.pumpWidget(hostData(const AcuteChronicLoad(
      acuteVolumeKg: 12000,
      chronicWeeklyVolumeKg: 8000,
      trend: LoadTrend.ramping,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Ramping up'), findsOneWidget);

    final gb = AppTheme.light().extension<GbColors>()!;
    final chip = tester.widget<Text>(find.text('Ramping up'));
    // Gentle amber tone — NOT the danger/red alarm.
    expect(chip.style?.color, gb.amberInk);
    expect(chip.style?.color, isNot(gb.danger));
  });

  testWidgets('trend chip mapping: steady → "Steady"', (tester) async {
    await tester.pumpWidget(hostData(const AcuteChronicLoad(
      acuteVolumeKg: 9000,
      chronicWeeklyVolumeKg: 9000,
      trend: LoadTrend.steady,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Steady'), findsOneWidget);
    expect(find.text('Ramping up'), findsNothing);
    expect(find.text('Easing off'), findsNothing);
  });

  testWidgets('trend chip mapping: detraining → "Easing off"', (tester) async {
    await tester.pumpWidget(hostData(const AcuteChronicLoad(
      acuteVolumeKg: 3000,
      chronicWeeklyVolumeKg: 9000,
      trend: LoadTrend.detraining,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Easing off'), findsOneWidget);

    final gb = AppTheme.light().extension<GbColors>()!;
    final chip = tester.widget<Text>(find.text('Easing off'));
    // Calm grey — never the red alarm.
    expect(chip.style?.color, isNot(gb.danger));
  });

  testWidgets('empty/zero state → quiet card, no bars, no chip, no caption', (tester) async {
    await tester.pumpWidget(hostData(const AcuteChronicLoad(
      acuteVolumeKg: 0,
      chronicWeeklyVolumeKg: 0,
      trend: LoadTrend.steady,
    )));
    await tester.pumpAndSettle();

    // The section header is still there, but the body is the honest quiet empty (not two empty bars
    // + a misleading "Steady" chip).
    expect(find.text('Workload'), findsOneWidget);
    expect(find.text('No training volume logged in this gym yet.'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
    expect(find.text('Steady'), findsNothing);
    expect(find.text('7-day vs 4-week weekly average · this gym only'), findsNothing);

    // The strength trends above are unaffected.
    expect(find.text('Strength trends'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
  });

  testWidgets('error → quiet card (NO ErrorRetry), strength trends still render', (tester) async {
    await tester.pumpWidget(host(AsyncError(Exception('boom'), StackTrace.empty)));
    await tester.pumpAndSettle();

    // The workload degrades to a quiet line — it must NOT surface an ErrorRetry that competes with /
    // blocks the strength section.
    expect(find.text("Workload isn't available right now."), findsOneWidget);
    expect(find.byType(ErrorRetry), findsNothing);

    // Strength trends are untouched (the page is not blocked on the workload read).
    expect(find.text('Strength trends'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('Workload'), findsOneWidget);
  });

  testWidgets('loading → skeleton, no bars/chip, strength trends already visible', (tester) async {
    await tester.pumpWidget(host(const AsyncLoading()));
    await tester.pump(); // let the strength (resolved) + workload (pending) providers settle a frame

    // No populated bars or trend chip while loading; the strength section is independent and shown.
    expect(find.text('This week'), findsNothing);
    expect(find.text('Steady'), findsNothing);
    expect(find.text('Strength trends'), findsOneWidget);
    expect(find.text('Workload'), findsOneWidget);
  });

  group('AcuteChronicLoad.fromJson', () {
    test('reads the frozen camelCase keys + parses the trend', () {
      final load = AcuteChronicLoad.fromJson(const {
        'acuteVolumeKg': 12000.0,
        'chronicWeeklyVolumeKg': 9000.5,
        'trend': 'ramping',
        'unit': 'kg',
      });
      expect(load.acuteVolumeKg, 12000.0);
      expect(load.chronicWeeklyVolumeKg, 9000.5);
      expect(load.trend, LoadTrend.ramping);
      expect(load.unit, 'kg');
      expect(load.hasData, isTrue);
      expect(load.peakKg, 12000.0);
    });

    test('defensive: missing/empty payload → zeroed, steady, no data', () {
      final load = AcuteChronicLoad.fromJson(const {});
      expect(load.acuteVolumeKg, 0);
      expect(load.chronicWeeklyVolumeKg, 0);
      expect(load.trend, LoadTrend.steady); // unknown/absent falls back to the neutral state
      expect(load.hasData, isFalse);
    });

    test('coerces string numbers and clamps negatives to zero', () {
      final load = AcuteChronicLoad.fromJson(const {
        'acuteVolumeKg': '5000',
        'chronicWeeklyVolumeKg': -10,
        'trend': 'DETRAINING',
      });
      expect(load.acuteVolumeKg, 5000);
      expect(load.chronicWeeklyVolumeKg, 0); // negative coerced to non-negative
      expect(load.trend, LoadTrend.detraining); // case-insensitive parse
    });
  });

  group('LoadTrend.parse', () {
    test('maps the three wire strings', () {
      expect(LoadTrend.parse('detraining'), LoadTrend.detraining);
      expect(LoadTrend.parse('steady'), LoadTrend.steady);
      expect(LoadTrend.parse('ramping'), LoadTrend.ramping);
    });

    test('case/whitespace tolerant + soft synonyms', () {
      expect(LoadTrend.parse(' Ramping '), LoadTrend.ramping);
      expect(LoadTrend.parse('ramping_up'), LoadTrend.ramping);
      expect(LoadTrend.parse('easing_off'), LoadTrend.detraining);
    });

    test('unknown/null → steady (neutral, no over-alarm)', () {
      expect(LoadTrend.parse('weird'), LoadTrend.steady);
      expect(LoadTrend.parse(null), LoadTrend.steady);
    });
  });
}
