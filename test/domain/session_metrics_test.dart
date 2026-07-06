import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/session_models.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:gymbroapp/domain/session_metrics.dart';

PerformedSet _set({
  int? reps,
  double? weightKg,
  int? rpe,
  bool completed = true,
}) =>
    PerformedSet(
      id: 's',
      setNumber: 1,
      setType: PerformedSetType.working,
      reps: reps,
      weightKg: weightKg,
      rpe: rpe,
      isCompleted: completed,
      loggedAt: null,
      isPr: false,
    );

PerformedExercise _ex(List<PerformedSet> sets) => PerformedExercise(
      id: 'e',
      exerciseId: 'x',
      order: 1,
      status: ExercisePerformStatus.inProgress,
      sets: sets,
    );

void main() {
  test('sumCompletedVolumeKg counts only completed sets', () {
    final ex = _ex([
      _set(reps: 10, weightKg: 60),
      _set(reps: 8, weightKg: 60),
      _set(reps: 8, weightKg: 60, completed: false), // excluded
    ]);
    expect(sumCompletedVolumeKg([ex]), 10 * 60 + 8 * 60);
  });

  test('averageCompletedRpe ignores null and incomplete', () {
    final ex = _ex([
      _set(reps: 5, rpe: 8),
      _set(reps: 5, rpe: 9),
      _set(reps: 5, rpe: 10, completed: false), // excluded
      _set(reps: 5), // no rpe
    ]);
    expect(averageCompletedRpe([ex]), 8.5);
  });

  test('computeProgressPercent clamps and handles zero total', () {
    expect(computeProgressPercent(0, 0), 0);
    expect(computeProgressPercent(2, 4), 50);
    expect(computeProgressPercent(5, 4), 100);
  });

  test('resolveTargetSetCount picks the max, with the active entry row', () {
    expect(resolveTargetSetCount(2, 4, false), 4); // planned dominates
    expect(
        resolveTargetSetCount(4, 3, true), 5); // logged + active row dominates
    expect(resolveTargetSetCount(0, 0, true), 1); // never below 1 when active
  });

  test('isPerformedExerciseComplete respects planned count', () {
    final ex = _ex([_set(), _set()]);
    expect(isPerformedExerciseComplete(ex, 3), isFalse);
    expect(isPerformedExerciseComplete(ex, 2), isTrue);
    expect(isPerformedExerciseComplete(_ex([]), 0),
        isFalse); // planned 0 never complete
  });

  test('epleyOneRepMax matches the server formula (Epley, 1dp)', () {
    expect(epleyOneRepMax(100, 5), 116.7); // 100 * (1 + 5/30) = 116.666..
    expect(epleyOneRepMax(0, 5), isNull);
    expect(epleyOneRepMax(60, 0), isNull);
  });

  test('formatDuration switches to H:MM:SS over an hour', () {
    expect(formatDuration(65), '01:05');
    expect(formatDuration(3661), '1:01:01');
  });

  test('formatLoggedSet shows cardio incline/speed/level, trimming .0', () {
    final treadmill = PerformedSet(
      id: 's',
      setNumber: 1,
      setType: PerformedSetType.working,
      durationSeconds: 1800,
      distanceM: 2400,
      inclinePercent: 8.5,
      speedKph: 5,
      level: 12,
      isCompleted: true,
      loggedAt: null,
      isPr: false,
    );
    // duration · distance · incline% · speed · level — 5.0 trims to 5, 8.5 stays.
    expect(formatLoggedSet(treadmill), '30:00 · 2400m · 8.5% · 5km/h · L12');
  });

  test('formatLoggedSet shows added load on a weighted timed hold', () {
    final weightedPlank = PerformedSet(
      id: 's',
      setNumber: 1,
      setType: PerformedSetType.working,
      durationSeconds: 60,
      weightKg: 10,
      isCompleted: true,
      loggedAt: null,
      isPr: false,
    );
    expect(formatLoggedSet(weightedPlank), '10kg · 01:00');
  });

  test('performedSetChip appends RPE only when logged', () {
    // Logged RPE shows; absent/zero RPE is omitted (never fabricated).
    expect(performedSetChip(_set(reps: 6, weightKg: 25, rpe: 8), 4),
        '4 · Working · 25kg × 6 · RPE 8');
    expect(performedSetChip(_set(reps: 12, weightKg: 10), 1),
        '1 · Working · 10kg × 12');
  });

  group('session-summary aggregates', () {
    PerformedSet st({
      PerformedSetType type = PerformedSetType.working,
      String? parent,
      int? reps,
      double? weight,
      int? duration,
      int? distance,
      int? cal,
      int? hr,
      int? rest,
    }) =>
        PerformedSet(
          id: 'x',
          setNumber: 1,
          setType: type,
          parentSetId: parent,
          reps: reps,
          weightKg: weight,
          durationSeconds: duration,
          distanceM: distance,
          calories: cal,
          avgHeartRate: hr,
          restSeconds: rest,
          isCompleted: true,
          loggedAt: null,
          isPr: false,
        );

    PerformedExercise exr(
            String id, ExerciseTrackingType tt, List<PerformedSet> sets,
            {LastPerformed? last}) =>
        PerformedExercise(
          id: 'e-$id',
          exerciseId: id,
          order: 1,
          status: ExercisePerformStatus.completed,
          trackingType: tt,
          sets: sets,
          lastPerformed: last,
        );

    test('workingSetCount excludes warmups and drop stages', () {
      final e = exr('a', ExerciseTrackingType.strength, [
        st(type: PerformedSetType.warmup, reps: 10, weight: 40),
        st(reps: 8, weight: 60),
        st(reps: 8, weight: 60),
        st(type: PerformedSetType.drop, parent: 'lead', reps: 6, weight: 40),
      ]);
      expect(workingSetCount([e]), 2);
      expect(warmupSetCount([e]), 1);
    });

    test('totalReps sums every set with reps', () {
      final e = exr('a', ExerciseTrackingType.strength,
          [st(reps: 10, weight: 40), st(reps: 8, weight: 60)]);
      expect(totalReps([e]), 18);
    });

    test('density and training load', () {
      expect(densityKgPerMin(600, 600)!.round(), 60); // 600kg / 10min
      expect(densityKgPerMin(0, 600), isNull);
      expect(sessionLoad(8, 1800), 240); // 8 × 30min
      expect(sessionLoad(null, 1800), isNull);
    });

    test('isCardioSession only when there is no lifting', () {
      expect(
          isCardioSession([
            exr('run', ExerciseTrackingType.cardio, [st(duration: 600)])
          ]),
          isTrue);
      expect(
          isCardioSession([
            exr('bench', ExerciseTrackingType.strength,
                [st(reps: 5, weight: 80)])
          ]),
          isFalse);
      expect(isCardioSession(const []), isFalse);
    });

    test('workingSetsByMuscle groups by primary muscle, sorted desc', () {
      final exs = [
        exr('a', ExerciseTrackingType.strength,
            [st(reps: 8, weight: 60), st(reps: 8, weight: 60)]),
        exr('b', ExerciseTrackingType.strength, [
          st(type: PerformedSetType.warmup, reps: 10),
          st(reps: 8, weight: 20),
        ]),
      ];
      final byM = workingSetsByMuscle(
          exs, (id) => {'a': 'Chest', 'b': 'Shoulders'}[id]);
      expect(byM, {'Chest': 2, 'Shoulders': 1});
      expect(byM.keys.first, 'Chest'); // busiest first
    });

    test('cardioTotals sums distance/duration/calories and means HR', () {
      final t = cardioTotals([
        exr('run', ExerciseTrackingType.cardio, [
          st(duration: 600, distance: 2000, cal: 150, hr: 140),
          st(duration: 300, distance: 1000, cal: 80, hr: 150),
        ])
      ]);
      expect(t.distanceM, 3000);
      expect(t.durationSeconds, 900);
      expect(t.calories, 230);
      expect(t.avgHeartRate, 145);
    });

    test('muscleInvolvement splits primary vs secondary, sorted by total', () {
      final exs = [
        exr('bench', ExerciseTrackingType.strength,
            [st(reps: 8, weight: 60), st(reps: 8, weight: 60)]),
        exr('raise', ExerciseTrackingType.strength, [
          st(type: PerformedSetType.warmup, reps: 10),
          st(reps: 12, weight: 8),
        ]),
      ];
      final muscles = {
        'bench': [
          (group: 'Chest', isPrimary: true),
          (group: 'Arms', isPrimary: false)
        ],
        'raise': [(group: 'Shoulders', isPrimary: true)],
      };
      final inv = muscleInvolvement(exs, (id) => muscles[id] ?? const []);
      expect(inv['Chest']!.primary, 2);
      expect(inv['Chest']!.secondary, 0);
      expect(inv['Arms']!.secondary, 2); // bench credits triceps as secondary
      expect(inv['Arms']!.primary, 0);
      expect(inv['Shoulders']!.primary, 1); // warmup excluded
      expect(inv.keys.first,
          anyOf('Chest', 'Arms')); // both total 2, ahead of Shoulders
    });

    test('liftProgress compares this top set vs lastPerformed e1RM', () {
      final up = liftProgress(exr(
          'a', ExerciseTrackingType.strength, [st(reps: 5, weight: 100)],
          last: const LastPerformed(weightKg: 95, reps: 5)));
      expect(up!.isUp, isTrue);

      final same = liftProgress(exr(
          'a', ExerciseTrackingType.strength, [st(reps: 5, weight: 100)],
          last: const LastPerformed(weightKg: 100, reps: 5)));
      expect(same!.isSame, isTrue);

      final down = liftProgress(exr(
          'a', ExerciseTrackingType.strength, [st(reps: 5, weight: 90)],
          last: const LastPerformed(weightKg: 100, reps: 5)));
      expect(down!.isDown, isTrue);

      // No prior reference → null (never fabricated).
      expect(
          liftProgress(exr(
              'a', ExerciseTrackingType.strength, [st(reps: 5, weight: 100)])),
          isNull);
    });

    test('sessionProgress rolls up only the compared lifts', () {
      final p = sessionProgress([
        exr('a', ExerciseTrackingType.strength, [st(reps: 5, weight: 100)],
            last: const LastPerformed(weightKg: 95, reps: 5)), // up
        exr('b', ExerciseTrackingType.strength, [st(reps: 5, weight: 90)],
            last: const LastPerformed(weightKg: 100, reps: 5)), // down
        exr('c', ExerciseTrackingType.strength,
            [st(reps: 5, weight: 80)]), // no prior → ignored
      ]);
      expect(p.up, 1);
      expect(p.down, 1);
      expect(p.compared, 2);
    });
  });

  group('suggestNextSet', () {
    SessionSnapshotSet snap({int? reps, double? weight, int? rpe}) =>
        SessionSnapshotSet(
          planSetId: 'p',
          order: 1,
          setType: PlanSetType.working,
          targetReps: reps,
          targetWeightKg: weight,
          targetRpe: rpe,
          restSeconds: 60,
        );

    // An already-logged in-session set of any type, for the [performedSets] feed.
    PerformedSet logged(PerformedSetType type,
            {required double weight, required int reps, int? rpe}) =>
        PerformedSet(
          id: 's',
          setNumber: 1,
          setType: type,
          reps: reps,
          weightKg: weight,
          rpe: rpe,
          isCompleted: true,
          loggedAt: null,
          isPr: false,
        );

    test('an explicit plan weight × reps wins (coach prescription)', () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        target: snap(reps: 6, weight: 50),
        lastPerformed: const LastPerformed(weightKg: 40, reps: 10),
      );
      expect(s, isNotNull);
      expect(s!.weightKg, 50);
      expect(s.reps, 6);
      expect(s.reason, 'Plan target');
    });

    test('reps + RPE without a plan weight autoregulates off the last-set e1RM',
        () {
      // last 100×5 → e1RM 116.7; reps 5 @ RPE 8 ≈ max set of 5+(10-8)=7 reps →
      // 116.7 / (1 + 7/30) ≈ 94.6 → rounds to 95kg.
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        target: snap(reps: 5, rpe: 8),
        lastPerformed: const LastPerformed(weightKg: 100, reps: 5),
      );
      expect(s, isNotNull);
      expect(s!.reps, 5);
      expect(s.weightKg, 95);
      expect(s.reason, 'RPE 8 target');
    });

    test(
        'no usable plan → last time + double-progression at the top of the range',
        () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        lastPerformed: const LastPerformed(weightKg: 50, reps: 12),
      );
      expect(s!.weightKg, 52.5); // +2.5kg
      expect(s.reps, 10); // drop reps to the bottom of the range
      expect(s.reason, 'Last time + 2.5kg');
    });

    test('no usable plan, mid-range → last time + 1 rep', () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        lastPerformed: const LastPerformed(weightKg: 60, reps: 8),
      );
      expect(s!.weightKg, 60);
      expect(s.reps, 9);
      expect(s.reason, 'Last time + 1 rep');
    });

    test('cardio gets no weight × reps suggestion', () {
      expect(
        suggestNextSet(
          trackingType: ExerciseTrackingType.cardio,
          setType: PerformedSetType.working,
          target: snap(reps: 5, weight: 100),
        ),
        isNull,
      );
    });

    test('no plan and no history → null (nothing honest to suggest)', () {
      expect(
        suggestNextSet(
          trackingType: ExerciseTrackingType.strength,
          setType: PerformedSetType.working,
        ),
        isNull,
      );
    });

    // ── Closed-loop: the suggestion must read the CURRENT session, not just last week. ──

    test(
        'regression: a hard, missed RPE-10 set pulls the next suggestion DOWN, '
        'not up off a stale last-session e1RM', () {
      // Last session top set 40×9 (e1RM 52) alone would suggest 37.5×12 for a 12 @ RPE10 target.
      // But today the lifter is grinding: warmup 25×12, then working 35×9 @ RPE10 (missed the 12).
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        target: snap(reps: 12, rpe: 10),
        lastPerformed: const LastPerformed(weightKg: 40, reps: 9),
        performedSets: [
          logged(PerformedSetType.warmup, weight: 25, reps: 12, rpe: 7),
          logged(PerformedSetType.working, weight: 35, reps: 9, rpe: 10),
        ],
      );
      // Anchored on today's 35×9 @ RPE10 (e1RM 45.5) → 45.5/1.4 = 32.5, never the stale 37.5.
      expect(s!.weightKg, 32.5);
      expect(s.reps, 12);
      expect(s.weightKg,
          lessThan(35)); // never heavier than the set you just ground out
      expect(s.reason, 'RPE 10 · this session');
    });

    test(
        'regression: a drop set is a fraction of the working weight, '
        'not the last-session working number', () {
      // Last session 40×9; today 35×9, 30×12, then a first drop 25×15. Entering a 2nd drop, no plan
      // target for that index → must NOT echo the 40×9 verbatim.
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.drop,
        lastPerformed: const LastPerformed(weightKg: 40, reps: 9),
        performedSets: [
          logged(PerformedSetType.working, weight: 35, reps: 9, rpe: 10),
          logged(PerformedSetType.working, weight: 30, reps: 12, rpe: 10),
          logged(PerformedSetType.drop, weight: 25, reps: 15, rpe: 9),
        ],
      );
      expect(s!.weightKg, 20); // steps ~20% down from the previous drop (25)
      expect(s.weightKg, lessThan(30)); // below the working sets
      expect(s.reason, 'Drop ~20% lighter');
    });

    test("today's in-session set overrides a stale, heavier last-session e1RM",
        () {
      // Last session was strong (100×5, e1RM 116.7) — naively 95kg — but today is only 60×5 @ RPE10.
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        target: snap(reps: 5, rpe: 8),
        lastPerformed: const LastPerformed(weightKg: 100, reps: 5),
        performedSets: [
          logged(PerformedSetType.working, weight: 60, reps: 5, rpe: 10),
        ],
      );
      expect(s!.reps, 5);
      expect(s.weightKg,
          57.5); // off today's 60×5 (e1RM 70), not last week's 116.7
      expect(s.reason, 'RPE 8 · this session');
    });

    test('drop with no prior drop steps ~20% down from the working weight', () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.drop,
        performedSets: [
          logged(PerformedSetType.working, weight: 30, reps: 12, rpe: 10),
        ],
      );
      expect(s!.weightKg, 25); // 30 × 0.80 = 24 → nearest 2.5kg plate = 25
      expect(s.reps, 12);
      expect(s.reason, 'Drop ~20% lighter');
    });

    test('warmup is ~50% of the working weight', () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.warmup,
        lastPerformed: const LastPerformed(weightKg: 60, reps: 5),
      );
      expect(s!.weightKg, 30); // 60 × 0.5
      expect(s.reason, 'Warmup ~50%');
    });

    test(
        'no plan, already lifting: an easy last set adds a rep at the same load',
        () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        performedSets: [
          logged(PerformedSetType.working, weight: 50, reps: 8, rpe: 6),
        ],
      );
      expect(s!.weightKg, 50); // hold the bar
      expect(s.reps, 9); // room to push
      expect(s.reason, 'Maintain · room to push');
    });

    test(
        'no plan, already lifting: a hard last set eases a rep at the same load',
        () {
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        performedSets: [
          logged(PerformedSetType.working, weight: 50, reps: 8, rpe: 10),
        ],
      );
      expect(s!.weightKg, 50);
      expect(s.reps, 7); // ease a rep
      expect(s.reason, 'Maintain · ease a rep');
    });

    test(
        'reps left in reserve correctly license a heavier true-rep-max load (RIR method)',
        () {
      // 30×12 @ RPE8 = 2 reps in reserve → behaves like a 14-rep max → e1RM ≈ 44 (Epley). A true 12-rep
      // max (RPE10) off that e1RM is 44 / (1 + 12/30) = 31.4 → 32.5. Going slightly heavier than the easy
      // 30 is the standard RIR prescription, NOT an over-suggestion — the bug was the OPPOSITE (going
      // heavier after a maxed-out set, which the closed-loop anchor now prevents).
      final s = suggestNextSet(
        trackingType: ExerciseTrackingType.strength,
        setType: PerformedSetType.working,
        target: snap(reps: 12, rpe: 10),
        performedSets: [
          logged(PerformedSetType.working, weight: 30, reps: 12, rpe: 8),
        ],
      );
      expect(s!.weightKg, 32.5);
      expect(s.reps, 12);
      expect(s.reason, 'RPE 10 · this session');
    });
  });

  group('muscleExerciseBreakdown', () {
    PerformedExercise exWith(String id, String name, int workingSets) =>
        PerformedExercise(
          id: id,
          exerciseId: id,
          exerciseName: name,
          order: 1,
          status: ExercisePerformStatus.inProgress,
          sets: [
            for (var i = 0; i < workingSets; i++)
              PerformedSet(
                id: '$id-$i',
                setNumber: i + 1,
                setType: PerformedSetType.working,
                reps: 8,
                weightKg: 50,
                isCompleted: true,
                loggedAt: null,
                isPr: false,
              ),
          ],
        );

    test('lists contributing exercises per group, primary movers first', () {
      final exercises = [
        exWith('rdl', 'Romanian Deadlift', 4), // Back primary
        exWith('pulldown', 'Lat Pulldown', 5), // Back primary
        exWith('curl', 'Biceps Curl', 3), // Arms primary, Back secondary
      ];
      const muscles = {
        'rdl': [(group: 'Back', isPrimary: true)],
        'pulldown': [(group: 'Back', isPrimary: true)],
        'curl': [
          (group: 'Arms', isPrimary: true),
          (group: 'Back', isPrimary: false),
        ],
      };

      final out = muscleExerciseBreakdown(
        exercises,
        (id) => muscles[id] ?? const [],
        (e) => e.exerciseName ?? '',
      );

      final back = out['Back']!;
      // Primary movers first (by sets desc), then secondary contributors.
      expect(back.map((c) => c.name).toList(),
          ['Lat Pulldown', 'Romanian Deadlift', 'Biceps Curl']);
      expect(back.first.isPrimary, isTrue);
      expect(back.first.sets, 5);
      expect(back.last.isPrimary, isFalse); // Biceps Curl assists Back
      expect(back.last.sets, 3);

      // Per-exercise sets sum back to the group's primary/secondary totals (matches muscleInvolvement).
      final prim =
          back.where((c) => c.isPrimary).fold<int>(0, (a, c) => a + c.sets);
      final sec =
          back.where((c) => !c.isPrimary).fold<int>(0, (a, c) => a + c.sets);
      expect(prim, 9); // 5 + 4
      expect(sec, 3);
    });
  });
}
