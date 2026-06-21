import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/progress_models.dart';

/// Wire-contract tests for the v2 window-differentiation fields on `GET /api/me/progress/overview`
/// (WINDOW-DIFFERENTIATION.md): the period stats, strength gain, muscle volume, load balance and the
/// coach's-read must parse from the camelCase JSON the API emits — and must degrade to empty-but-valid
/// defaults when the keys are absent (a pre-v2 payload, or a thin user), never throwing.
void main() {
  group('ProgressOverview v2 parsing', () {
    test('parses the full v2 payload', () {
      final o = ProgressOverview.fromJson({
        'thisWeek': {'completedSessions': 3, 'goal': 4, 'hasActivePlan': true},
        'consistency': {'windowWeeks': 4, 'days': [], 'currentStreakWeeks': 2},
        'topLifts': [],
        'recentPrs': [],
        'period': {
          'sessions': 6,
          'prevSessions': 5,
          'volumeKg': 12400.0,
          'prevVolumeKg': 11000.0,
          'workingSets': 60,
          'prevWorkingSets': 52,
          'prCount': 3,
          'weeklyVolumeKg': [2000.0, 2500.0, 3000.0, 4900.0],
        },
        'strengthGain': {
          'avgGainPct': 9.0,
          'lifts': [
            {
              'exerciseId': 'e1',
              'exerciseName': 'Bench Press',
              'startE1rmKg': 92.0,
              'currentE1rmKg': 100.0,
              'gainKg': 8.0,
              'gainPct': 8.7,
              'plateauWeeks': 0,
            },
          ],
        },
        'muscleVolume': [
          {'muscle': 'chest', 'setsPerWeek': 14.0, 'prevSetsPerWeek': 12.0},
          {'muscle': 'legs', 'setsPerWeek': 8.0, 'prevSetsPerWeek': 7.0},
        ],
        'load': {
          'acuteVolumeKg': 4900.0,
          'chronicWeeklyVolumeKg': 3000.0,
          'trend': 'ramping',
        },
        'coach': {
          'headline': "Momentum's with you",
          'detail': '2 lifts trending up.',
          'action': 'Legs is light this block — add a set.',
          'tone': 'positive',
        },
      });

      expect(o.period.sessions, 6);
      expect(o.period.prevSessions, 5);
      expect(o.period.volumeKg, 12400.0);
      expect(o.period.prCount, 3);
      expect(o.period.weeklyVolumeKg, [2000.0, 2500.0, 3000.0, 4900.0]);
      // (12400 - 11000) / 11000 ≈ 0.127
      expect(o.period.volumeDelta, closeTo(0.127, 0.001));

      expect(o.strengthGain.avgGainPct, 9.0);
      expect(o.strengthGain.lifts.single.gainKg, 8.0);
      expect(o.strengthGain.lifts.single.plateauWeeks, 0);

      expect(o.muscleVolume.length, 2);
      expect(o.muscleVolume.first.muscle, 'chest');
      expect(o.muscleVolume.first.setsPerWeek, 14.0);

      expect(o.load.acuteVolumeKg, 4900.0);
      expect(o.load.chronicWeeklyVolumeKg, 3000.0);
      expect(o.load.trend, LoadTrend.ramping);

      expect(o.coach.headline, "Momentum's with you");
      expect(o.coach.action, 'Legs is light this block — add a set.');
      expect(o.coach.tone, CoachTone.positive);
      expect(o.coach.hasContent, isTrue);
    });

    test('degrades to empty-but-valid defaults when v2 keys are absent', () {
      // A pre-v2 / thin payload — only the Phase-1 fields.
      final o = ProgressOverview.fromJson({
        'thisWeek': {'completedSessions': 0, 'hasActivePlan': false},
        'consistency': {'windowWeeks': 12, 'days': [], 'currentStreakWeeks': 0},
        'topLifts': [],
        'recentPrs': [],
      });

      expect(o.period.sessions, 0);
      expect(o.period.volumeKg, 0);
      expect(o.period.weeklyVolumeKg, isEmpty);
      expect(o.period.volumeDelta, isNull); // no prior baseline
      expect(o.strengthGain.lifts, isEmpty);
      expect(o.strengthGain.avgGainPct, 0);
      expect(o.muscleVolume, isEmpty);
      expect(o.load.trend, LoadTrend.steady);
      expect(o.coach.hasContent, isFalse);
    });

    test('enum parsing is tolerant of case and unknown values', () {
      expect(LoadTrend.parse('Ramping'), LoadTrend.ramping);
      expect(LoadTrend.parse('DETRAINING'), LoadTrend.detraining);
      expect(LoadTrend.parse(null), LoadTrend.steady); // unknown → safe default
      expect(LoadTrend.parse('garbage'), LoadTrend.steady);

      expect(CoachTone.parse('watch'), CoachTone.watch);
      expect(CoachTone.parse('POSITIVE'), CoachTone.positive);
      expect(CoachTone.parse(null), CoachTone.neutral);
      expect(CoachTone.parse('???'), CoachTone.neutral);
    });
  });
}
