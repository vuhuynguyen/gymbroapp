import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/data/repositories/progress_repository.dart';
import 'package:gymbroapp/features/progress/progress_providers.dart';
import 'package:gymbroapp/features/progress/progress_screen.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Progress page PERIOD control + the per-section "How this is counted"
/// transparency sheets.
///
/// Both behaviours are driven through the real providers against a fake [ProgressRepository] (no Dio,
/// no network): the period control writes [progressPeriodWeeksProvider], which the overview /
/// nutrition / e1RM providers watch and re-request with the matching window — so a tap is observable
/// as a new `weeks` value reaching the repo. The info sheets are static copy, so we just open one and
/// assert the right text.
void main() {
  /// A non-new-user overview (it has a PR) so the data ListView — and thus the period bar + section
  /// headers — renders, not the first-run hero.
  ProgressOverview nonEmptyOverview() => const ProgressOverview(
        thisWeek: WeekAdherence(completedSessions: 2, hasActivePlan: false),
        consistency:
            Consistency(windowWeeks: 12, days: [], currentStreakWeeks: 0),
        topLifts: [
          LiftDirection(
            exerciseId: 'e1',
            exerciseName: 'Bench Press',
            currentE1rmKg: 100,
            direction: LiftTrendDirection.up,
            stalled: false,
            stallSessions: 0,
            sparkE1rmKg: [90, 95, 98, 100],
          ),
        ],
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

  /// A v2 overview with the window-differentiation payload populated, for the 4w/12w split test.
  ProgressOverview v2Overview() => const ProgressOverview(
        thisWeek:
            WeekAdherence(completedSessions: 3, goal: 4, hasActivePlan: true),
        consistency: Consistency(
            windowWeeks: 12, days: [], consistencyPct: 80, currentStreakWeeks: 3),
        topLifts: [
          LiftDirection(
            exerciseId: 'e1',
            exerciseName: 'Bench Press',
            currentE1rmKg: 100,
            direction: LiftTrendDirection.up,
            stalled: false,
            stallSessions: 0,
            sparkE1rmKg: [90, 95, 98, 100],
          ),
        ],
        recentPrs: [
          PersonalRecord(
            exerciseId: 'p1',
            exerciseName: 'Deadlift',
            weightKg: 140,
            reps: 3,
            estimatedOneRepMaxKg: 153,
          ),
        ],
        period: PeriodStats(
          sessions: 6,
          prevSessions: 5,
          volumeKg: 12400,
          prevVolumeKg: 11000,
          workingSets: 60,
          prevWorkingSets: 52,
          prCount: 3,
          weeklyVolumeKg: [2000, 2500, 3000, 4900],
        ),
        strengthGain: StrengthGain(
          avgGainPct: 9,
          lifts: [
            LiftGain(
              exerciseId: 'e1',
              exerciseName: 'Bench Press',
              startE1rmKg: 92,
              currentE1rmKg: 100,
              gainKg: 8,
              gainPct: 8.7,
              plateauWeeks: 0,
            ),
          ],
        ),
        muscleVolume: [
          MuscleVolume(muscle: 'chest', setsPerWeek: 14, prevSetsPerWeek: 12),
          MuscleVolume(muscle: 'legs', setsPerWeek: 8, prevSetsPerWeek: 7),
        ],
        load: LoadBalance(
          acuteVolumeKg: 4900,
          chronicWeeklyVolumeKg: 3000,
          trend: LoadTrend.ramping,
        ),
        coach: CoachRead(
          headline: "Momentum's with you",
          detail: '2 lifts trending up, volume up 13% on the last block.',
          action: 'Legs is light this block — add a set.',
          tone: CoachTone.positive,
        ),
      );

  /// Finds an info button by the `label` on its [Semantics] widget (robust against semantics-node
  /// merging in the dark hero). Each Progress section's info button is `_InfoButton`, which wraps its
  /// tap target in `Semantics(button: true, label: 'How <Section> is counted')`.
  Finder infoButton(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );

  Future<void> pump(
    WidgetTester tester,
    _FakeProgressRepository repo, {
    bool tallViewport = false,
  }) async {
    if (tallViewport) {
      // A tall viewport so the whole page — period bar AND the bottom Nutrition section — mounts at
      // once, so the nutrition provider subscribes without scrolling the period control out of view.
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The whole Progress surface (overview / e1RM / metrics / nutrition) goes through this one
          // fake — so every period-driven re-request is recorded, fully off-network.
          progressRepositoryProvider.overrideWithValue(repo),
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

  // ── Period control ──────────────────────────────────────────────────────────

  testWidgets('defaults to 12w and requests the overview with weeks=12',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    await pump(tester, repo);

    // Two top tabs — Today + the merged Trends — with Trends' window sub-filter (Week / 4w / 12w)
    // visible because Week (a trend window) is the default.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('4w'), findsOneWidget);
    expect(find.text('12w'), findsOneWidget);

    // The initial overview fetch threaded the default window (Week = 1).
    expect(repo.overviewWeeks, contains(1));
  });

  testWidgets('Today hides the trend-window sub-filter; Trends restores it',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    await pump(tester, repo);

    // Default is a trend window, so the Week / 4w / 12w sub-filter is visible.
    expect(find.text('4w'), findsOneWidget);
    expect(find.text('12w'), findsOneWidget);

    // Today is a snapshot, not a trend window → the sub-filter is hidden.
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('4w'), findsNothing);
    expect(find.text('12w'), findsNothing);

    // Back to Trends → the sub-filter returns (on the remembered window).
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('4w'), findsOneWidget);
  });

  testWidgets(
      'changing the period re-requests the overview with the new weeks value',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    await pump(tester, repo);

    // Baseline: only the default-Week request so far.
    expect(repo.overviewWeeks, [1]);

    // Tap 4w → the overview provider re-runs and re-requests with weeks=4.
    await tester.tap(find.text('4w'));
    await tester.pumpAndSettle();
    expect(repo.overviewWeeks.last, 4);

    // Tap Week → re-requests with the 1-week window.
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(repo.overviewWeeks.last, 1);
  });

  testWidgets(
      'changing the period also re-requests the nutrition trend with the new window',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    // A tall viewport mounts the bottom Nutrition section + the top period bar together, so the
    // nutrition provider is subscribed when the period changes.
    await pump(tester, repo, tallViewport: true);

    // The default-Week fetch already threaded a 1-week (7-day) window.
    expect(repo.nutritionFroms, isNotEmpty);
    final (f0, t0) = repo.nutritionFroms.first;
    expect(t0!.difference(f0!).inDays, 7); // 7 * 1 week (default)

    final before = repo.nutritionFroms.length;

    // Tap 4w → the nutrition provider re-runs; the latest window spans ~4 weeks (28 days).
    await tester.tap(find.text('4w'));
    await tester.pumpAndSettle();
    expect(repo.nutritionFroms.length, greaterThan(before));
    final (from, to) = repo.nutritionFroms.last;
    expect(to!.difference(from!).inDays, 28); // 7 * 4 weeks
  });

  // ── v2 window differentiation: 4w block vs 12w phase ────────────────────────

  testWidgets('4w shows the block scorecard; 12w shows the phase + muscle balance',
      (tester) async {
    final repo = _FakeProgressRepository(v2Overview());
    await pump(tester, repo, tallViewport: true);

    // 4w (block): the coach's-read verdict leads, a block tile is present, and the structural-balance
    // card — a PHASE concern — is absent.
    await tester.tap(find.text('4w'));
    await tester.pumpAndSettle();
    expect(find.text("Momentum's with you"), findsOneWidget);
    expect(find.text('LIFTS IMPROVING'), findsOneWidget);
    expect(find.text('SETS / MUSCLE · PER WEEK'), findsNothing);

    // 12w (phase): the phase tile + the structural-balance hero appear; the block-only tile is gone.
    await tester.tap(find.text('12w'));
    await tester.pumpAndSettle();
    expect(find.text("Momentum's with you"), findsOneWidget);
    expect(find.text('VOLUME TREND'), findsOneWidget);
    expect(find.text('SETS / MUSCLE · PER WEEK'), findsOneWidget);
    expect(find.text('LIFTS IMPROVING'), findsNothing);
  });

  // ── "How this is counted" transparency sheets ────────────────────────────────

  testWidgets('Strength info button opens a sheet with the strength copy',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    await pump(tester, repo);

    await tester.scrollUntilVisible(find.text('STRENGTH'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // The info button next to the STRENGTH title.
    await tester.tap(infoButton('How Strength is counted'));
    await tester.pumpAndSettle();

    // The sheet header + the exact strength copy.
    expect(find.text('How Strength is counted'), findsOneWidget);
    expect(
      find.textContaining(
          'Estimated 1RM per lift from your top working set (Epley formula), over the selected period.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('at least 4 qualifying sessions'),
      findsOneWidget,
    );
  });

  testWidgets('This Week info button opens a sheet with the this-week copy',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    await pump(tester, repo);
    await tester
        .tap(find.text('Week')); // the This Week hero is on the Week window
    await tester.pumpAndSettle();

    // The hero "This week" info button is at the top — no scroll needed.
    await tester.tap(infoButton('How This Week is counted'));
    await tester.pumpAndSettle();

    expect(find.text('How This Week is counted'), findsOneWidget);
    expect(
      find.textContaining(
          'Completed sessions in the current week (Mon to Sun, your time zone) versus your weekly plan goal.'),
      findsOneWidget,
    );
    expect(find.textContaining('Rest days count'), findsOneWidget);
  });

  testWidgets('Nutrition info button opens a sheet with the nutrition copy',
      (tester) async {
    final repo = _FakeProgressRepository(nonEmptyOverview());
    await pump(tester, repo);

    await tester.scrollUntilVisible(find.text('NUTRITION'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    await tester.tap(infoButton('How Nutrition is counted'));
    await tester.pumpAndSettle();

    expect(find.text('How Nutrition is counted'), findsOneWidget);
    expect(
      find.textContaining('Calories you logged each day (all foods).'),
      findsOneWidget,
    );
  });
}

/// A fake repository recording the `weeks` overview requests + the nutrition from/to windows — no Dio,
/// no network. Returns the supplied overview; everything else degrades to an empty-but-valid payload.
class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository(this._overview);
  final ProgressOverview _overview;

  /// Every `weeks` value the screen has requested the overview with (in order).
  final List<int?> overviewWeeks = [];

  /// Every (from, to) window the screen has requested the nutrition trend with.
  final List<(DateTime?, DateTime?)> nutritionFroms = [];

  @override
  Future<ProgressOverview> overview({int? weeks}) async {
    overviewWeeks.add(weeks);
    return _overview;
  }

  @override
  Future<ExerciseE1rmSeries> exerciseE1rmSeries(
    String exerciseId, {
    DateTime? from,
    DateTime? to,
  }) async =>
      ExerciseE1rmSeries.fromJson({'exerciseId': exerciseId});

  /// Every `weeks` value the screen has requested the strength-lifts list with (in order).
  final List<int?> strengthWeeks = [];

  @override
  Future<StrengthLifts> strengthLifts({int? weeks, String? muscleGroup}) async {
    strengthWeeks.add(weeks);
    return StrengthLifts.fromJson(const {});
  }

  @override
  Future<MetricSeries> metricSeries(String type, {DateTime? from}) async =>
      MetricSeries(type: type, unit: 'kg', points: const []);

  @override
  Future<void> setGoalWeight(double kg) async {}

  @override
  Future<NutritionAdherence> nutritionAdherence({
    DateTime? from,
    DateTime? to,
  }) async {
    nutritionFroms.add((from, to));
    return NutritionAdherence.fromJson(const {});
  }
}
