import '../../data/models/nutrition_models.dart';
import '../../data/models/progress_models.dart';

/// Tone of a Today tip — drives its colour/icon in the UI. Kept Flutter-free so the engine stays a
/// pure, unit-testable function.
enum TipTone { good, warn, info }

/// One grounded coaching tip. Never fabricated: a tip is only produced when its underlying data
/// exists, so a missing weigh-in / sleep entry / plan simply yields fewer tips (never a fake one).
class TodayTip {
  const TodayTip(this.tone, this.title, this.detail);
  final TipTone tone;
  final String title;
  final String detail;
}

/// Today's at-a-glance facts (null where unlogged) — the snapshot tiles shown above the tips.
class TodaySnapshot {
  const TodaySnapshot({
    this.consumedKcal,
    this.targetKcal,
    this.proteinG,
    this.sleepHours,
    this.weightKg,
    this.sessionsThisWeek,
    this.weeklyGoal,
  });
  final int? consumedKcal;
  final int? targetKcal;
  final int? proteinG;
  final double? sleepHours;
  final double? weightKg;
  final int? sessionsThisWeek;
  final int? weeklyGoal;
}

class TodayInsights {
  const TodayInsights({required this.snapshot, required this.tips});
  final TodaySnapshot snapshot;
  final List<TodayTip> tips;
}

/// Build the Today snapshot + advice from whatever's been logged. Pure & deterministic — pass [now]
/// (the widget passes `DateTime.now()`; tests pass a fixed instant). Tip order = priority: actionable
/// warnings first, then progress, then celebration. Honours the never-fabricate rule: every tip is
/// gated on real data.
TodayInsights buildTodayInsights({
  DailyNutritionLog? nutrition,
  DailyCheckin? checkin,
  ProgressOverview? overview,
  List<double> weightTrend = const [],
  required DateTime now,
}) {
  final tips = <TodayTip>[];

  final loggedAnything =
      nutrition?.allItems.any((i) => i.status.isAdherent) ?? false;
  final week = overview?.thisWeek;

  final snapshot = TodaySnapshot(
    consumedKcal: nutrition != null && (nutrition.hasPlan || loggedAnything)
        ? nutrition.consumedKcal
        : null,
    targetKcal: nutrition?.targetKcal,
    proteinG: (nutrition?.loggedProtein ?? 0) > 0
        ? nutrition!.loggedProtein.round()
        : null,
    sleepHours: checkin?.sleepHours?.toDouble(),
    weightKg: checkin?.weightKg?.toDouble(),
    sessionsThisWeek: week?.completedSessions,
    weeklyGoal: week?.goal,
  );

  // ── Nutrition ──────────────────────────────────────────────────────────────
  if (nutrition != null) {
    final t = nutrition.targetKcal;
    final itemsLeft = nutrition.plannedCount - nutrition.completedCount;
    if (nutrition.hasPlan && !loggedAnything) {
      tips.add(const TodayTip(TipTone.warn, 'Log today’s meals',
          'You haven’t logged any food yet today.'));
    } else if (t != null && t > 0) {
      final c = nutrition.consumedKcal;
      if (c > t * 1.1) {
        tips.add(
            TodayTip(TipTone.warn, 'Over your calories', '$c / $t kcal today.'));
      } else if (c >= t * 0.9) {
        tips.add(
            TodayTip(TipTone.good, 'Calories on target', '$c / $t kcal today.'));
      } else if (itemsLeft > 0) {
        tips.add(TodayTip(
            TipTone.info,
            '$itemsLeft item${itemsLeft == 1 ? '' : 's'} left to log',
            '$c / $t kcal so far — a few planned items to go.'));
      } else {
        tips.add(TodayTip(
            TipTone.info, 'Under your target', '$c / $t kcal today.'));
      }
    }
  }

  // ── Sleep (last night) ───────────────────────────────────────────────────────
  final sleep = checkin?.sleepHours?.toDouble();
  if (sleep != null && sleep > 0) {
    final h = _fmtNum(sleep);
    if (sleep < 6) {
      tips.add(TodayTip(TipTone.warn, 'Low on sleep',
          'You slept ${h}h last night — aim for 7–9h to recover well.'));
    } else if (sleep < 7) {
      tips.add(TodayTip(TipTone.info, 'A little short on sleep',
          '${h}h last night — just under the 7–9h sweet spot.'));
    } else {
      tips.add(TodayTip(
          TipTone.good, 'Well rested', '${h}h of sleep last night — nice.'));
    }
  }

  // ── Weekly workouts ──────────────────────────────────────────────────────────
  if (week != null) {
    final g = week.goal;
    if (week.hasActivePlan && g != null && g > 0) {
      if (week.completedSessions >= g) {
        tips.add(TodayTip(TipTone.good, 'Weekly goal hit \u{1F389}',
            '${week.completedSessions} of $g sessions done this week.'));
      } else {
        final left = g - week.completedSessions;
        final daysLeft = _daysLeftInWeek(week.weekStart, now);
        final tail = daysLeft != null
            ? ' · $daysLeft day${daysLeft == 1 ? '' : 's'} left'
            : '';
        tips.add(TodayTip(
            TipTone.info,
            '${week.completedSessions} of $g workouts this week',
            '$left more to hit your weekly goal$tail.'));
      }
    } else if (week.completedSessions > 0) {
      tips.add(TodayTip(
          TipTone.info,
          '${week.completedSessions} workout${week.completedSessions == 1 ? '' : 's'} this week',
          'Keep the momentum going.'));
    }
  }

  // ── Streak ───────────────────────────────────────────────────────────────────
  final streak = overview?.consistency.currentStreakWeeks ?? 0;
  if (streak >= 2) {
    tips.add(TodayTip(TipTone.good, 'On a $streak-week streak \u{1F525}',
        'You’ve hit your goal $streak weeks running.'));
  }

  // ── Recent PR ────────────────────────────────────────────────────────────────
  final prs = overview?.recentPrs ?? const <PersonalRecord>[];
  if (prs.isNotEmpty) {
    final pr = prs.first;
    final name = pr.exerciseName ?? 'a lift';
    tips.add(TodayTip(TipTone.good, 'Recent PR \u{1F4AA}',
        '$name — ${_fmtKg(pr.estimatedOneRepMaxKg)} estimated 1RM.'));
  }

  // ── Weight trend (only with enough points) ──────────────────────────────────
  if (weightTrend.length >= 2) {
    final delta = weightTrend.last - weightTrend.first;
    if (delta.abs() >= 0.5) {
      final dir = delta < 0 ? 'down' : 'up';
      tips.add(TodayTip(TipTone.info, 'Weight trending $dir',
          '${_fmtKg(delta.abs())} $dir over the recent window.'));
    }
  }

  return TodayInsights(snapshot: snapshot, tips: tips);
}

String _fmtNum(double v) => v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
String _fmtKg(double v) =>
    v % 1 == 0 ? '${v.toInt()}kg' : '${v.toStringAsFixed(1)}kg';

/// Days remaining in the Monday-anchored week (including today), or null if [weekStart] is missing or
/// [now] falls outside that week (a stale overview).
int? _daysLeftInWeek(DateTime? weekStart, DateTime now) {
  if (weekStart == null) return null;
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final today = DateTime(now.year, now.month, now.day);
  final elapsed = today.difference(start).inDays;
  if (elapsed < 0 || elapsed > 6) return null;
  return 7 - elapsed;
}
