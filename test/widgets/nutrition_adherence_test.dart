import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Phase-3 conditional Nutrition-adherence card on the trainee Progress home
/// (MOBILE-DASHBOARD §5 / Decision **D13**). The card is private, so we drive it through
/// [ProgressScreen]: a non-new-user overview renders the data ListView, the Body provider is kept
/// quiet (empty weigh-ins), and [nutritionAdherenceProvider] carries the fixture under test.
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

  DailyAdherence day(int pct) => DailyAdherence(pct: pct, date: DateTime(2026, 6, 10));

  Future<void> pump(
    WidgetTester tester,
    AsyncValue<NutritionAdherence> adherence,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressOverviewProvider
              .overrideWith((ref) async => nonEmptyOverview()),
          // Keep the Body section quiet (no weigh-ins → invite) and goal null, so the only thing under
          // test is the Nutrition card.
          bodyweightSeriesProvider.overrideWith(
              (ref) async => const MetricSeries(type: 'weight', points: [])),
          goalWeightProvider.overrideWith((ref) async => null),
          nutritionAdherenceProvider.overrideWith((ref) async {
            return adherence.when(
              data: (d) => d,
              loading: () => throw StateError('use a resolved value'),
              error: (e, _) => throw e,
            );
          }),
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

  /// Scroll the lazy ListView until [finder] is built + visible (Nutrition sits below the fold).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }

  testWidgets('hasPlan=false → "follow a meal plan" invite, no ring', (tester) async {
    await pump(
      tester,
      const AsyncData(NutritionAdherence(hasPlan: false, recentDays: [])),
    );
    await scrollTo(tester, find.text('NUTRITION'));

    expect(find.text('NUTRITION'), findsOneWidget); // section title renders
    expect(
      find.text('Follow a meal plan to track nutrition adherence.'),
      findsOneWidget,
    );
    // No adherence ring on the no-plan state (a 0% ring would read as failure).
    expect(find.byType(GbRing), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('hasPlan=true but no closed days → "close out a day" nudge, no invite',
      (tester) async {
    await pump(
      tester,
      const AsyncData(NutritionAdherence(hasPlan: true, recentDays: [])),
    );
    await scrollTo(tester, find.text('NUTRITION'));

    expect(find.text('NUTRITION'), findsOneWidget);
    expect(
      find.text('Close out a day to see your nutrition adherence.'),
      findsOneWidget,
    );
    // NOT the no-plan invite.
    expect(
      find.text('Follow a meal plan to track nutrition adherence.'),
      findsNothing,
    );
  });

  testWidgets('hasPlan=true with data → week ring + caption, no invite', (tester) async {
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: true,
        currentWeekAvgPct: 84,
        recentDays: [day(90), day(70), day(100), day(80), day(80)],
      )),
    );
    await scrollTo(tester, find.text('Avg 84% this week · 5 days logged'));

    // The current-week ring shows the rolled-up average…
    expect(find.byType(GbRing), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    // …and the caption restates avg + days logged.
    expect(find.text('Avg 84% this week · 5 days logged'), findsOneWidget);
    // No invite copy when there's data.
    expect(
      find.text('Follow a meal plan to track nutrition adherence.'),
      findsNothing,
    );
  });

  testWidgets('data but no week roll-up → strip + days-logged caption, no ring', (tester) async {
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: true,
        currentWeekAvgPct: null,
        recentDays: [day(60), day(75)],
      )),
    );
    await scrollTo(tester, find.text('2 days logged'));

    // No ring without a week average, but the strip + a days-logged caption still render.
    expect(find.byType(GbRing), findsNothing);
    expect(find.text('2 days logged'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets); // the bar strip painter
  });

  testWidgets('nutrition provider errors → card stays quiet, page unblocked', (tester) async {
    await pump(
      tester,
      AsyncError(Exception('nutrition down'), StackTrace.empty),
    );

    // The page is unaffected — the PR teaser still renders, no page-level error.
    await scrollTo(tester, find.text('PERSONAL RECORDS'));
    expect(find.text('PERSONAL RECORDS'), findsOneWidget);
    expect(find.text('Deadlift'), findsOneWidget);
    expect(find.byType(ErrorRetry), findsNothing);
    // The Nutrition section collapses entirely on error (no title, no invite).
    expect(find.text('NUTRITION'), findsNothing);
    expect(
      find.text('Follow a meal plan to track nutrition adherence.'),
      findsNothing,
    );
  });

  // Parse-level coverage against the FROZEN wire contract (API-CONTRACTS §5,
  // `NutritionAdherenceDto`/`DailyAdherenceDto` serialized camelCase). The widget tests above build
  // models via constructors and never exercise `fromJson`, so a key-name mismatch (e.g. reading
  // `recentDays`/`date`/`pct` instead of `days`/`localDate`/`adherencePct`) would slip past them and
  // silently empty the card on a real 200. These guard that exact regression.
  group('NutritionAdherence.fromJson — frozen wire keys', () {
    // The literal frozen payload: NutritionAdherenceDto(HasPlan, Days, CurrentWeekAvgPct) with
    // DailyAdherenceDto(LocalDate, AdherencePct, PlannedCount, CompletedCount), camelCase.
    final frozenPayload = <String, dynamic>{
      'hasPlan': true,
      'currentWeekAvgPct': 84,
      'days': [
        {
          'localDate': '2026-06-10',
          'adherencePct': 90,
          'plannedCount': 5,
          'completedCount': 5,
        },
        {
          'localDate': '2026-06-11',
          'adherencePct': 70,
          'plannedCount': 5,
          'completedCount': 3,
        },
      ],
    };

    test('reads days/localDate/adherencePct from the frozen payload', () {
      final a = NutritionAdherence.fromJson(frozenPayload);

      expect(a.hasPlan, isTrue);
      expect(a.currentWeekAvgPct, 84);
      // The series must NOT be empty — this is the bug class the field-name fix closes.
      expect(a.recentDays, hasLength(2));
      expect(a.isEmpty, isFalse);

      final first = a.recentDays.first;
      expect(first.date, DateTime(2026, 6, 10));
      expect(first.pct, 90);
      expect(a.recentDays.last.pct, 70);
    });

    test('never-planned empty-invite shape parses to hasPlan:false, empty', () {
      final a = NutritionAdherence.fromJson(const {
        'hasPlan': false,
        'days': <dynamic>[],
        'currentWeekAvgPct': null,
      });

      expect(a.hasPlan, isFalse);
      expect(a.recentDays, isEmpty);
      expect(a.isEmpty, isTrue);
      expect(a.currentWeekAvgPct, isNull);
    });

    test('clamps out-of-range adherencePct to 0–100', () {
      final a = NutritionAdherence.fromJson(const {
        'hasPlan': true,
        'days': [
          {'localDate': '2026-06-10', 'adherencePct': 140},
          {'localDate': '2026-06-11', 'adherencePct': -5},
        ],
      });

      expect(a.recentDays.map((d) => d.pct), [100, 0]);
    });
  });
}
