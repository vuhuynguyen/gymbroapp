import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the rebuilt conditional Nutrition **CALORIES TREND** card on the trainee Progress
/// home (MOBILE-DASHBOARD §5 / Decision **D13**, rebuilt). The card is private, so we drive it through
/// [ProgressScreen]: a non-new-user overview renders the data ListView, the Body provider is kept quiet
/// (empty weigh-ins), and [nutritionAdherenceProvider] carries the fixture under test.
///
/// Honesty contract under test: consumed-kcal bars render for both plan AND no-plan users (data is
/// all-source); the dashed "Plan" target line appears ONLY where `targetKcal` is present; a day without
/// a target never gets a fabricated target/deficit/surplus/%; and the advice line is built only from
/// real numbers.
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

  /// One day in the trend: consumed kcal (all-source) and an optional plan target.
  DailyAdherence day(int consumed, {int? target, int pct = 100}) =>
      DailyAdherence(
        pct: pct,
        date: DateTime(2026, 6, 10),
        consumedKcal: consumed,
        targetKcal: target,
      );

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

  // ── Empty / nudge / invite states ───────────────────────────────────────────

  testWidgets('no logging at all → "log your food" invite, no ring/%', (tester) async {
    await pump(
      tester,
      const AsyncData(NutritionAdherence(
        hasPlan: false,
        recentDays: [],
        hasAnyLogging: false,
        loggedDaysThisWeek: 0,
      )),
    );
    await scrollTo(tester, find.text('NUTRITION'));

    expect(find.text('NUTRITION'), findsOneWidget); // section title renders
    expect(
      find.text('Log your food to see your calories trend.'),
      findsOneWidget,
    );
    // No ring / no fabricated % on the no-data state.
    expect(find.byType(GbRing), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('hasPlan=true but no closed days → "close out a day" nudge', (tester) async {
    await pump(
      tester,
      const AsyncData(NutritionAdherence(hasPlan: true, recentDays: [])),
    );
    await scrollTo(tester, find.text('NUTRITION'));

    expect(find.text('NUTRITION'), findsOneWidget);
    expect(
      find.text('Close out a day to see your calories trend.'),
      findsOneWidget,
    );
    expect(
      find.text('Log your food to see your calories trend.'),
      findsNothing,
    );
  });

  testWidgets('no plan + ad-hoc logging but empty window → keep-logging nudge', (tester) async {
    await pump(
      tester,
      const AsyncData(NutritionAdherence(
        hasPlan: false,
        recentDays: [],
        hasAnyLogging: true,
        loggedDaysThisWeek: 2,
      )),
    );
    await scrollTo(tester, find.text('NUTRITION'));

    expect(
      find.text('Keep logging to see your calories trend.'),
      findsOneWidget,
    );
    expect(find.byType(GbRing), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  // ── Bars render from consumedKcal (both plan and no-plan, all-source) ─────────

  testWidgets('no-plan ad-hoc days → consumed-kcal bars render, no ring/%', (tester) async {
    // Self-logging without a plan now gets the SAME consumed-kcal bars (data is all-source); the days
    // carry no target, so there is NO dashed plan line and NO deficit/surplus claim.
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: false,
        hasAnyLogging: true,
        loggedDaysThisWeek: 4,
        recentDays: [day(2100), day(2300), day(1900), day(2200)],
      )),
    );
    await scrollTo(tester, find.text('CALORIES TREND'));

    // The trend card renders (the consumed-kcal bar painter, CustomPaint — no chart lib).
    expect(find.text('CALORIES TREND'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // The honest days-logged sub-caption.
    expect(find.text('4 DAYS LOGGED · THIS WEEK'), findsOneWidget);
    // Never a fabricated ring / % / target on a no-target ad-hoc window.
    expect(find.byType(GbRing), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('under plan'), findsNothing);
    expect(find.textContaining('over plan'), findsNothing);
  });

  testWidgets('plan days with targets → trend card + a target painter, no % ring', (tester) async {
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: true,
        currentWeekAvgPct: 84,
        loggedDaysThisWeek: 5,
        recentDays: [
          day(2000, target: 2200),
          day(2400, target: 2200),
          day(2100, target: 2200),
          day(2300, target: 2200),
          day(2050, target: 2200),
        ],
      )),
    );
    await scrollTo(tester, find.text('CALORIES TREND'));

    expect(find.text('CALORIES TREND'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('5 DAYS LOGGED · THIS WEEK'), findsOneWidget);
    // The rebuilt card is calories-first: NO adherence ring, NO % readout (D13 vs-target honesty).
    expect(find.byType(GbRing), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  // ── Advice text matches the data ──────────────────────────────────────────────

  testWidgets('no targets in window → advice describes avg kcal/day over logged days', (tester) async {
    // 2000, 2100, 2200 → avg 2100; no targets anywhere → describe the trend, never a deficit/surplus.
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: false,
        hasAnyLogging: true,
        loggedDaysThisWeek: 3,
        recentDays: [day(2000), day(2100), day(2200)],
      )),
    );
    await scrollTo(
        tester, find.text('Averaging ~2100 kcal/day over your logged days.'));

    expect(
      find.text('Averaging ~2100 kcal/day over your logged days.'),
      findsOneWidget,
    );
    // No fabricated under/over-plan claim without targets.
    expect(find.textContaining('under plan'), findsNothing);
    expect(find.textContaining('over plan'), findsNothing);
  });

  testWidgets('targets on most days → honest "~N kcal under plan on logged days"', (tester) async {
    // Consumed under target by 200 each on the targeted days → "~200 kcal under plan".
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: true,
        currentWeekAvgPct: 90,
        loggedDaysThisWeek: 4,
        recentDays: [
          day(2000, target: 2200),
          day(2000, target: 2200),
          day(2000, target: 2200),
          day(2000, target: 2200),
        ],
      )),
    );
    await scrollTo(
        tester, find.text('Averaging ~200 kcal under plan on logged days.'));

    expect(
      find.text('Averaging ~200 kcal under plan on logged days.'),
      findsOneWidget,
    );
  });

  testWidgets('targets on most days, over → "~N kcal over plan on logged days"', (tester) async {
    // Consumed over target by 300 each → "~300 kcal over plan".
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: true,
        loggedDaysThisWeek: 3,
        recentDays: [
          day(2500, target: 2200),
          day(2500, target: 2200),
          day(2500, target: 2200),
        ],
      )),
    );
    await scrollTo(
        tester, find.text('Averaging ~300 kcal over plan on logged days.'));

    expect(
      find.text('Averaging ~300 kcal over plan on logged days.'),
      findsOneWidget,
    );
  });

  testWidgets('target present on SOME days only → advice never invents a target for the others', (tester) async {
    // 4 logged days, only 1 has a target (< half) → advice MUST fall back to the avg-kcal trend, never
    // claim a deficit/surplus from the days that have no target. avg(2000,2100,2200,2300)=2150.
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: false,
        hasAnyLogging: true,
        loggedDaysThisWeek: 4,
        recentDays: [
          day(2000, target: 2200),
          day(2100),
          day(2200),
          day(2300),
        ],
      )),
    );
    await scrollTo(
        tester, find.text('Averaging ~2150 kcal/day over your logged days.'));

    expect(
      find.text('Averaging ~2150 kcal/day over your logged days.'),
      findsOneWidget,
    );
    // No fabricated deficit/surplus, even though one day happens to carry a target.
    expect(find.textContaining('under plan'), findsNothing);
    expect(find.textContaining('over plan'), findsNothing);
  });

  testWidgets('sparse logging (<3 days) → "log more for a useful trend" nudge', (tester) async {
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: false,
        hasAnyLogging: true,
        loggedDaysThisWeek: 2,
        recentDays: [day(2000), day(2100)],
      )),
    );
    await scrollTo(
        tester, find.text('Only 2 days logged — log more for a useful trend.'));

    expect(
      find.text('Only 2 days logged — log more for a useful trend.'),
      findsOneWidget,
    );
    // Sub-caption matches the count.
    expect(find.text('2 DAYS LOGGED · THIS WEEK'), findsOneWidget);
  });

  testWidgets('roughly on target → "right around your plan target" (no false deficit/surplus)', (tester) async {
    // Avg delta < 50 kcal in magnitude → neither under nor over; an honest "right around".
    await pump(
      tester,
      AsyncData(NutritionAdherence(
        hasPlan: true,
        loggedDaysThisWeek: 3,
        recentDays: [
          day(2210, target: 2200),
          day(2190, target: 2200),
          day(2200, target: 2200),
        ],
      )),
    );
    await scrollTo(
        tester, find.text('Right around your plan target on logged days.'));

    expect(
      find.text('Right around your plan target on logged days.'),
      findsOneWidget,
    );
    expect(find.textContaining('under plan'), findsNothing);
    expect(find.textContaining('over plan'), findsNothing);
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
    // The Nutrition section collapses entirely on error (no title, no trend).
    expect(find.text('NUTRITION'), findsNothing);
    expect(find.text('CALORIES TREND'), findsNothing);
  });

  // ── Parse-level coverage against the wire contract (API-CONTRACTS §5) ─────────
  //
  // The widget tests above build models via constructors and never exercise `fromJson`, so a key-name
  // mismatch (e.g. reading `recentDays`/`date`/`pct` instead of `days`/`localDate`/`adherencePct`, or
  // missing the new `consumedKcal`/`targetKcal`) would slip past them. These guard those regressions.
  group('NutritionAdherence.fromJson — frozen wire keys + calories fields', () {
    // The frozen payload now carries per-day consumedKcal (all-source) + targetKcal (plan-derived).
    final frozenPayload = <String, dynamic>{
      'hasPlan': true,
      'currentWeekAvgPct': 84,
      'loggedDaysThisWeek': 5,
      'hasAnyLogging': true,
      'days': [
        {
          'localDate': '2026-06-10',
          'adherencePct': 90,
          'plannedCount': 5,
          'completedCount': 5,
          'consumedKcal': 2100,
          'targetKcal': 2200,
        },
        {
          'localDate': '2026-06-11',
          'adherencePct': 70,
          'plannedCount': 5,
          'completedCount': 3,
          'consumedKcal': 2400,
          'targetKcal': 2200,
        },
      ],
    };

    test('reads consumedKcal/targetKcal alongside the frozen keys', () {
      final a = NutritionAdherence.fromJson(frozenPayload);

      expect(a.hasPlan, isTrue);
      expect(a.currentWeekAvgPct, 84);
      expect(a.loggedDaysThisWeek, 5);
      expect(a.hasAnyLogging, isTrue);
      expect(a.recentDays, hasLength(2));

      final first = a.recentDays.first;
      expect(first.date, DateTime(2026, 6, 10));
      expect(first.pct, 90);
      expect(first.consumedKcal, 2100);
      expect(first.targetKcal, 2200);
      expect(a.recentDays.last.consumedKcal, 2400);
      expect(a.recentDays.last.targetKcal, 2200);
    });

    test('day with NO targetKcal parses to null (never fabricated) and keeps consumed', () {
      final a = NutritionAdherence.fromJson(const {
        'hasPlan': false,
        'days': [
          {'localDate': '2026-06-10', 'adherencePct': 100, 'consumedKcal': 1950},
        ],
        'hasAnyLogging': true,
        'loggedDaysThisWeek': 1,
      });

      final d = a.recentDays.single;
      expect(d.consumedKcal, 1950);
      expect(d.targetKcal, isNull); // no target on the wire → null, not a guess
    });

    test('older payload without consumedKcal/targetKcal defaults to 0 / null (defensive)', () {
      final a = NutritionAdherence.fromJson(const {
        'hasPlan': true,
        'currentWeekAvgPct': 80,
        'days': [
          {'localDate': '2026-06-10', 'adherencePct': 90},
        ],
      });

      final d = a.recentDays.single;
      expect(d.consumedKcal, 0); // missing consumed → 0
      expect(d.targetKcal, isNull); // missing target → null
      expect(a.loggedDaysThisWeek, 0);
      expect(a.hasAnyLogging, isFalse);
    });

    test('ad-hoc-only payload parses to hasPlan:false + hasAnyLogging:true', () {
      final a = NutritionAdherence.fromJson(const {
        'hasPlan': false,
        'days': <dynamic>[],
        'currentWeekAvgPct': null,
        'loggedDaysThisWeek': 3,
        'hasAnyLogging': true,
      });

      expect(a.hasPlan, isFalse);
      expect(a.recentDays, isEmpty);
      expect(a.hasAnyLogging, isTrue);
      expect(a.loggedDaysThisWeek, 3);
    });

    test('clamps out-of-range adherencePct to 0–100', () {
      final a = NutritionAdherence.fromJson(const {
        'hasPlan': true,
        'days': [
          {'localDate': '2026-06-10', 'adherencePct': 140, 'consumedKcal': 2000},
          {'localDate': '2026-06-11', 'adherencePct': -5, 'consumedKcal': 1800},
        ],
      });

      expect(a.recentDays.map((d) => d.pct), [100, 0]);
    });
  });
}
