import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
// widgets.dart re-exports the theme barrel, so this single import yields AppTheme,
// GbColors, GbRing, EmptyState, ErrorRetry, GbSkeletonList, GbTappableRow, etc.
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Phase-1 trainee Progress home (PHASE-1 §5 states + §1 red discipline).
///
/// Every test overrides [progressOverviewProvider] directly so nothing touches the network — the
/// repo/Dio layer is never constructed. The provider is a `FutureProvider.autoDispose`, so an
/// override of the form `overrideWith((ref) async => fixture)` (or a throwing/never-completing body)
/// drives the screen's `.when()` loading / error / data branches deterministically.
void main() {
  // ── Fixtures ──────────────────────────────────────────────────────────────

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

  Consistency consistency({
    List<ConsistencyDay> days = const [],
    int? pct,
    int streak = 0,
    int windowWeeks = 12,
  }) =>
      Consistency(
        windowWeeks: windowWeeks,
        days: days,
        consistencyPct: pct,
        currentStreakWeeks: streak,
      );

  LiftDirection lift({
    required String id,
    required String name,
    required LiftTrendDirection direction,
    double e1rm = 100,
    bool stalled = false,
    int stallSessions = 0,
    List<double> spark = const [90, 95, 100],
  }) =>
      LiftDirection(
        exerciseId: id,
        exerciseName: name,
        currentE1rmKg: e1rm,
        direction: direction,
        stalled: stalled,
        stallSessions: stallSessions,
        sparkE1rmKg: spark,
      );

  PersonalRecord pr({
    required String id,
    required String name,
    double weight = 100,
    int reps = 5,
    double e1rm = 116,
    DateTime? at,
  }) =>
      PersonalRecord(
        exerciseId: id,
        exerciseName: name,
        weightKg: weight,
        reps: reps,
        estimatedOneRepMaxKg: e1rm,
        achievedAt: at,
      );

  ProgressOverview overview({
    WeekAdherence? thisWeek,
    Consistency? cons,
    List<LiftDirection> lifts = const [],
    List<PersonalRecord> prs = const [],
  }) =>
      ProgressOverview(
        thisWeek: thisWeek ?? week(),
        consistency: cons ?? consistency(),
        topLifts: lifts,
        recentPrs: prs,
      );

  /// The conditional Section-5 providers (Body / Nutrition) load independently of the overview and,
  /// once their widgets scroll into the lazy ListView, would otherwise fire a real Dio call. Stub them
  /// to their quiet empty-states so these overview-focused tests stay fully off-network and
  /// deterministic regardless of how far the page scrolls (mirrors body_section_test's isolation).
  final offNetworkSections = <Override>[
    bodyweightSeriesProvider.overrideWith(
        (ref) async => const MetricSeries(type: 'weight', points: [])),
    sleepSeriesProvider.overrideWith(
        (ref) async => const MetricSeries(type: 'sleep', points: [])),
    goalWeightProvider.overrideWith((ref) async => null),
    nutritionAdherenceProvider.overrideWith(
        (ref) async => const NutritionAdherence(hasPlan: false, recentDays: [])),
    // The Strength section watches strengthLiftsProvider for its muscle chips + picker. Stub it empty
    // so these overview-focused tests stay off-network — the "All" glance strip (driven by the
    // overview's topLifts) renders unchanged regardless.
    strengthLiftsProvider
        .overrideWith((ref) async => const StrengthLifts(lifts: [])),
  ];

  /// Pumps [ProgressScreen] with [progressOverviewProvider] overridden to resolve to [data].
  Future<void> pumpData(WidgetTester tester, ProgressOverview data) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressOverviewProvider.overrideWith((ref) async => data),
          ...offNetworkSections,
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

  /// Scroll the lazy data ListView until [finder] is built + visible. The Graphite restyle gives the
  /// page a taller glance layer (the 86px hero ring, 24px section rhythm), so the lower sections
  /// (Consistency, Personal records) now sit below the default test viewport and must be scrolled to —
  /// the same pattern the Body/Nutrition tests already use.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }

  Widget hostWith(Override override, {bool settle = false}) => ProviderScope(
        overrides: [override, ...offNetworkSections],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ProgressScreen(),
            ),
          ),
        ),
      );

  // ── §5 states ─────────────────────────────────────────────────────────────

  testWidgets('loading → bespoke hero-shaped skeleton (shimmer), never the red ErrorRetry', (tester) async {
    // A never-completing future keeps the provider in AsyncLoading.
    final completer = Completer<ProgressOverview>();
    await tester.pumpWidget(
      hostWith(progressOverviewProvider.overrideWith((ref) => completer.future)),
    );
    // One frame only — do NOT settle (the future never resolves).
    await tester.pump();

    // The bespoke _LoadingBody (design LoadingBody) renders shimmer placeholders, NOT the generic
    // GbSkeletonList. Several GbSkeleton shimmers are present (lift rows + the big bar + heatmap cells).
    expect(find.byType(GbSkeletonList), findsNothing);
    expect(find.byType(GbSkeleton), findsWidgets);
    // Still no page-level error tile while loading.
    expect(find.byType(ErrorRetry), findsNothing);

    // Resolve so the autoDispose future doesn't dangle past the test.
    completer.complete(overview());
    await tester.pumpAndSettle();
  });

  testWidgets('error → neutral Graphite panel with a Retry control, never the red ErrorRetry', (tester) async {
    await tester.pumpWidget(
      hostWith(progressOverviewProvider
          .overrideWith((ref) async => throw Exception('boom'))),
    );
    await tester.pumpAndSettle();

    // The neutral _ErrorBody (design ErrorBody) — NOT the shared red ErrorRetry tile (PHASE-1 §1: the
    // only red is a per-lift slipping tag, never a page-level state).
    expect(find.byType(ErrorRetry), findsNothing);
    expect(find.text('Couldn\'t load your progress'), findsOneWidget);
    expect(
      find.text('Check your connection and try again — your data is safe.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // No skeleton in the error state, and explicitly no red danger error tile.
    expect(find.byType(GbSkeletonList), findsNothing);
    // No red error iconography (the old ErrorRetry used error_outline / a danger tile).
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('new user → first-run hero (headline + sub-line + Start CTA + 3 preview cards), no sections', (tester) async {
    // isNewUser: 0 sessions, no consistency days, no lifts, no PRs.
    await pumpData(tester, overview());

    // The old generic EmptyState is gone — the design NewUserBody renders the dark hero panel.
    expect(find.byType(EmptyState), findsNothing);
    expect(
      find.text('Start your first session to begin tracking.'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Your progress is built from your own sessions — no fake numbers to start.'),
      findsOneWidget,
    );
    // The white CTA routes to the existing /start flow.
    expect(find.text('Start a workout'), findsOneWidget);
    // The mono "what you'll see here" eyebrow + the three preview titles (future content, non-fabricated).
    expect(find.text('WHAT YOU\'LL SEE HERE'), findsOneWidget);
    expect(find.text('Strength trend'), findsOneWidget);
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('Personal records'), findsOneWidget);

    // The four section titles (uppercased, tracked SectionTitle) must NOT render in the hero state.
    expect(find.text('STRENGTH'), findsNothing);
    expect(find.text('CONSISTENCY'), findsNothing);
    expect(find.text('PERSONAL RECORDS'), findsNothing);
  });

  testWidgets('no active plan → ring hidden, raw completed count shown', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 2, hasPlan: false),
        // Make it not a new user (has a PR) so the four sections render.
        prs: [pr(id: 'p1', name: 'Deadlift')],
      ),
    );
    await tester.tap(find.text('Week')); // the This Week hero lives on the Week tab now
    await tester.pumpAndSettle();

    // No-plan substitutes the GbRing with the design's big raw count: "2" + a mono "SESSIONS THIS
    // WEEK" sub-label (uppercased data-channel label).
    expect(find.byType(GbRing), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('SESSIONS THIS WEEK'), findsOneWidget);
    expect(find.text('STRENGTH'), findsOneWidget); // sections present
  });

  testWidgets('active plan → ring shown with completed/goal', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(
          completed: 3,
          goal: 4,
          hasPlan: true,
          start: DateTime.now(),
        ),
        prs: [pr(id: 'p1', name: 'Squat')],
      ),
    );
    await tester.tap(find.text('Week')); // the This Week hero lives on the Week tab now
    await tester.pumpAndSettle();

    expect(find.byType(GbRing), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget); // ring center label
  });

  testWidgets('This Week shows only on the Week tab; Consistency only on multi-week',
      (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 2, goal: 4, hasPlan: true, start: DateTime.now()),
        prs: [pr(id: 'p1', name: 'Squat')],
      ),
    );

    // Default is the Week tab: the current-week hero IS shown; the multi-week Consistency heatmap is
    // not (it lives only on the 4w / 12w windows).
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('Consistency'), findsNothing);

    // Switch to a multi-week window: the hero drops away entirely from the tree.
    await tester.tap(find.text('12w'));
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK'), findsNothing);
  });

  testWidgets('empty top-lifts → strength invite copy', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        // No lifts, but a PR keeps us out of the new-user hero.
        prs: [pr(id: 'p1', name: 'Bench Press')],
      ),
    );

    expect(
      find.text('Log a few working sets to see your strength trend.'),
      findsOneWidget,
    );
  });

  testWidgets('empty PRs → quiet placeholder copy', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        // A lift keeps us out of the new-user hero; recentPrs is empty.
        lifts: [lift(id: 'e1', name: 'Overhead Press', direction: LiftTrendDirection.flat)],
      ),
    );
    await scrollTo(tester, find.text('Your PRs will appear here.'));

    expect(find.text('Your PRs will appear here.'), findsOneWidget);
  });

  testWidgets('ConsistencyPct null → percent caption hidden', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        cons: consistency(pct: null, streak: 0),
        prs: [pr(id: 'p1', name: 'Row')],
      ),
    );
    // Consistency lives only on the multi-week windows now (not the default Week tab).
    await tester.tap(find.text('12w'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('CONSISTENCY'));

    // With null pct and no streak, no big-% header — no "%" anywhere on the page.
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('CONSISTENCY'), findsOneWidget); // section still renders
  });

  testWidgets(
      'no goal (pct null) but ad-hoc sessions → SESSIONS · LAST 12 WKS caption, not "%", no streak chip',
      (tester) async {
    // Self-training without a plan: no "% hit goal", but the completed ad-hoc sessions in `days` must
    // still COUNT — the card headlines the total session count instead of an empty percent.
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        cons: consistency(
          pct: null,
          streak: 0,
          days: const [
            ConsistencyDay(date: null, sessionCount: 2),
            ConsistencyDay(date: null, sessionCount: 1),
          ],
        ),
        prs: [pr(id: 'p1', name: 'Row')],
      ),
    );
    await tester.tap(find.text('12w'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('SESSIONS · LAST 12 WKS'));

    // Big number = sum of sessionCount (2 + 1 = 3), with the sessions/window caption.
    expect(find.text('3'), findsWidgets);
    expect(find.text('SESSIONS · LAST 12 WKS'), findsOneWidget);
    // Never a fabricated "% hit goal" on the no-goal state…
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('HIT GOAL · LAST 12 WKS'), findsNothing);
    // …and the goal-relative streak chip is dropped without a goal.
    expect(find.textContaining('wk streak'), findsNothing);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets('with goal (pct set) → "% HIT GOAL" + streak chip render unchanged', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 3, goal: 4, hasPlan: true, start: DateTime.now()),
        cons: consistency(
          pct: 78,
          streak: 5,
          days: const [ConsistencyDay(date: null, sessionCount: 1)],
        ),
        prs: [pr(id: 'p1', name: 'Row')],
      ),
    );
    await tester.tap(find.text('12w'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('HIT GOAL · LAST 12 WKS'));

    // The with-goal header is exactly as before: big % + the "hit goal" label + the streak flame chip.
    // The big number lives in a Text.rich ("78" + "%" spans), so match the rendered text.
    expect(find.textContaining('78'), findsWidgets); // big % number
    expect(find.textContaining('%'), findsWidgets); // the "%" suffix span
    expect(find.text('HIT GOAL · LAST 12 WKS'), findsOneWidget);
    expect(find.text('5 WK STREAK'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    // The no-goal sessions caption must NOT appear when there is a goal.
    expect(find.text('SESSIONS · LAST 12 WKS'), findsNothing);
  });

  testWidgets('consistency "% hit goal" caption reflects the selected window (not a frozen 12)',
      (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 3, goal: 4, hasPlan: true, start: DateTime.now()),
        cons: consistency(
          windowWeeks: 8,
          pct: 78,
          streak: 5,
          days: const [ConsistencyDay(date: null, sessionCount: 1)],
        ),
        prs: [pr(id: 'p1', name: 'Row')],
      ),
    );
    await tester.tap(find.text('12w'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('HIT GOAL · LAST 8 WKS'));

    // The subtitle must track the effective window from the period selector, never a hardcoded 12.
    expect(find.text('HIT GOAL · LAST 8 WKS'), findsOneWidget);
    expect(find.text('HIT GOAL · LAST 12 WKS'), findsNothing);
  });

  // ── §1 red discipline + direction tags ──────────────────────────────────────

  testWidgets('direction down → red "Slipping" tag; headline never red', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        lifts: [
          lift(id: 'e1', name: 'Bench Press', direction: LiftTrendDirection.down),
        ],
      ),
    );
    await tester.tap(find.text('Week')); // the This Week hero lives on the Week tab now
    await tester.pumpAndSettle();

    // The down lift renders the only red on the page — the "Slipping" tag, now on the design's honest
    // neg channel (sparkColor → progNeg #AD3B32), the SAME tint as the row's sparkline.
    final gb = AppTheme.light().extension<GbColors>()!;
    final slipping = tester.widget<Text>(find.text('Slipping'));
    expect(slipping.style?.color, gb.progNeg);

    // The headline must never be red (PHASE-1 §1). It's the neutral sessions line here.
    final headline = tester.widget<Text>(find.text('1 session this week'));
    expect(headline.style?.color, isNot(gb.progNeg));
    expect(headline.style?.color, isNot(gb.danger));
  });

  testWidgets('up lift → green headline mentioning the lift, never red', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 2, hasPlan: false),
        lifts: [
          lift(id: 'e1', name: 'Barbell Bench Press', direction: LiftTrendDirection.up),
        ],
      ),
    );
    await tester.tap(find.text('Week')); // the This Week hero lives on the Week tab now
    await tester.pumpAndSettle();

    final gb = AppTheme.light().extension<GbColors>()!;
    // The verdict headline now lives in the dark "This week" hero: it reads "bench up · 2 sessions
    // this week" on white hero ink (the " up" fragment is a hero-pos green span), and is NEVER red.
    final headline = tester.widget<Text>(find.textContaining('up ·'));
    expect(headline.style?.color, Colors.white); // hero foreground
    expect(headline.style?.color, isNot(gb.danger));
    // The hero-pos "up" fragment is green — extract it from the rich text spans.
    final spanColors = <Color?>[];
    headline.textSpan?.visitChildren((span) {
      if (span is TextSpan) spanColors.add(span.style?.color);
      return true;
    });
    expect(spanColors, contains(const Color(0xFF74E6B0))); // --hero-pos
    expect(spanColors, isNot(contains(gb.danger)));

    // The up DirTag label is green on the design's honest channel (sparkColor → progPos #157A4A) —
    // the SAME tint the row's sparkline uses, never red, and no longer the old app emeraldInk.
    final tag = tester.widget<Text>(find.text('Up'));
    expect(tag.style?.color, gb.progPos);
    expect(tag.style?.color, isNot(gb.danger));
  });

  testWidgets('flat stalled lift → "Flat N×" tag in warn-amber', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        lifts: [
          lift(
            id: 'e1',
            name: 'Squat',
            direction: LiftTrendDirection.flat,
            stalled: true,
            stallSessions: 3,
          ),
        ],
      ),
    );

    final gb = AppTheme.light().extension<GbColors>()!;
    // Flat now reads warn-amber (sparkColor → progWarn #8A6312) per the design's DirTag — an attention
    // tone, not the old neutral grey, and still never red.
    final tag = tester.widget<Text>(find.text('Flat 3×'));
    expect(tag.style?.color, gb.progWarn);
    expect(tag.style?.color, isNot(gb.danger));
  });

  testWidgets('PR rows are display-only — no chevron leaks through', (tester) async {
    await pumpData(
      tester,
      overview(
        thisWeek: week(completed: 1, hasPlan: false),
        prs: [pr(id: 'p1', name: 'Deadlift', at: DateTime.now())],
      ),
    );
    await scrollTo(tester, find.text('Deadlift'));

    expect(find.text('Deadlift'), findsOneWidget);
    // The PR row is display-only — the Graphite design carries no chevron / tap-through in Phase 1.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
