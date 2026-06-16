import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/nutrition_models.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:gymbroapp/features/progress/today_insights.dart';

DailyNutritionLog _nutrition({
  bool hasPlan = false,
  int consumed = 0,
  int? target,
}) =>
    DailyNutritionLog(
      id: 'd',
      localDate: '2026-06-16',
      hasPlan: hasPlan,
      isClosed: false,
      source: SessionSource.adhoc,
      meals: const [],
      consumedKcal: consumed,
      targetKcal: target,
    );

ProgressOverview _overview({
  int completed = 0,
  int? goal,
  bool hasPlan = true,
  int streak = 0,
  DateTime? weekStart,
  List<PersonalRecord> prs = const [],
}) =>
    ProgressOverview(
      thisWeek: WeekAdherence(
        weekStart: weekStart,
        completedSessions: completed,
        goal: goal,
        hasActivePlan: hasPlan,
      ),
      consistency: Consistency(
          windowWeeks: 12, days: const [], currentStreakWeeks: streak),
      topLifts: const [],
      recentPrs: prs,
    );

List<TodayTip> _tipsOf(TodayInsights i) => i.tips;
bool _has(TodayInsights i, String titleFragment) =>
    i.tips.any((t) => t.title.contains(titleFragment));

void main() {
  final now = DateTime(2026, 6, 16); // a Tuesday

  group('buildTodayInsights — never fabricates', () {
    test('all-null inputs yield no tips and an empty snapshot', () {
      final i = buildTodayInsights(now: now);
      expect(_tipsOf(i), isEmpty);
      expect(i.snapshot.consumedKcal, isNull);
      expect(i.snapshot.sleepHours, isNull);
      expect(i.snapshot.sessionsThisWeek, isNull);
    });
  });

  group('sleep', () {
    test('under 6h warns', () {
      final i = buildTodayInsights(checkin: const DailyCheckin(sleepHours: 5), now: now);
      expect(i.tips.single.tone, TipTone.warn);
      expect(i.tips.single.title, 'Low on sleep');
    });
    test('6–7h is an info nudge', () {
      final i = buildTodayInsights(checkin: const DailyCheckin(sleepHours: 6.5), now: now);
      expect(i.tips.single.tone, TipTone.info);
    });
    test('7h+ is positive', () {
      final i = buildTodayInsights(checkin: const DailyCheckin(sleepHours: 8), now: now);
      expect(i.tips.single.tone, TipTone.good);
      expect(i.snapshot.sleepHours, 8);
    });
  });

  group('calories', () {
    test('over target warns', () {
      final i = buildTodayInsights(
          nutrition: _nutrition(consumed: 2300, target: 2000), now: now);
      expect(_has(i, 'Over your calories'), isTrue);
      expect(i.tips.first.tone, TipTone.warn);
    });
    test('within 10% of target is on-target', () {
      final i = buildTodayInsights(
          nutrition: _nutrition(consumed: 1950, target: 2000), now: now);
      expect(_has(i, 'Calories on target'), isTrue);
    });
    test('well under target is an info tip', () {
      final i = buildTodayInsights(
          nutrition: _nutrition(consumed: 900, target: 2000), now: now);
      expect(_has(i, 'Under your target'), isTrue);
    });
    test('a plan with nothing logged prompts to log meals', () {
      final i = buildTodayInsights(
          nutrition: _nutrition(hasPlan: true, target: 2000), now: now);
      expect(_has(i, 'Log today'), isTrue);
      expect(i.tips.first.tone, TipTone.warn);
    });
  });

  group('workouts / streak / PR', () {
    test('hitting the weekly goal celebrates', () {
      final i = buildTodayInsights(
          overview: _overview(completed: 4, goal: 4), now: now);
      expect(_has(i, 'Weekly goal hit'), isTrue);
    });
    test('below goal shows remaining + days left', () {
      final i = buildTodayInsights(
          overview: _overview(
              completed: 2, goal: 4, weekStart: DateTime(2026, 6, 15)),
          now: now);
      final tip = i.tips.firstWhere((t) => t.title.contains('of 4'));
      expect(tip.tone, TipTone.info);
      expect(tip.detail, contains('2 more'));
      expect(tip.detail, contains('days left'));
    });
    test('a 2+ week streak is celebrated', () {
      final i = buildTodayInsights(overview: _overview(streak: 3), now: now);
      expect(_has(i, '3-week streak'), isTrue);
    });
    test('a recent PR is surfaced', () {
      final i = buildTodayInsights(
          overview: _overview(prs: const [
            PersonalRecord(
                exerciseId: 'x',
                exerciseName: 'Bench Press',
                weightKg: 100,
                reps: 5,
                estimatedOneRepMaxKg: 116.7),
          ]),
          now: now);
      final tip = i.tips.firstWhere((t) => t.title.contains('Recent PR'));
      expect(tip.detail, contains('Bench Press'));
    });
  });

  test('weight trend tip needs a real move (≥0.5kg)', () {
    final flat = buildTodayInsights(weightTrend: const [80, 80.2], now: now);
    expect(flat.tips.where((t) => t.title.contains('Weight trending')), isEmpty);
    final down = buildTodayInsights(weightTrend: const [81, 79.5], now: now);
    expect(down.tips.any((t) => t.title.contains('Weight trending down')), isTrue);
  });
}
