import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/shared/widgets/muscle_map.dart';

/// The catalog only knows coarse muscle GROUPS ("Legs"), so the map infers the specific muscles from the
/// exercise name — otherwise a hamstring curl would light the entire leg (the reported bug).
void main() {
  test('Lying Leg Curl → hamstrings, NOT quadriceps', () {
    final inv = muscleMapInvolvement('Lying Leg Curl', ['Legs'], []);
    expect(inv['hamstring'], 2); // primary
    expect(inv['quadriceps'], 0); // the bug was lighting these
    expect(inv['gluteal']! > 0, isTrue); // secondary
  });

  test('Leg Extension → quadriceps, NOT hamstrings', () {
    final inv = muscleMapInvolvement('Leg Extension', ['Legs'], []);
    expect(inv['quadriceps'], 2);
    expect(inv['hamstring'], 0);
  });

  test('Standing Calf Raise → calves only', () {
    final inv = muscleMapInvolvement('Standing Calf Raise', ['Legs'], []);
    expect(inv['calves'], 2);
    expect(inv['quadriceps'], 0);
    expect(inv['hamstring'], 0);
  });

  test('Barbell Bench Press → chest primary, triceps/delts secondary', () {
    final inv = muscleMapInvolvement('Barbell Bench Press', ['Chest'], ['Arms', 'Shoulders']);
    expect(inv['chest'], 2);
    expect(inv['triceps'], 1);
    expect(inv['deltoids'], 1);
  });

  test('unknown leg exercise falls back to the whole leg group', () {
    final inv = muscleMapInvolvement('Mystery Leg Machine', ['Legs'], []);
    expect(inv['quadriceps'], 2);
    expect(inv['hamstring'], 2); // coarse fallback lights the whole group
    expect(inv['calves'], 2);
  });

  test('hasContent is true for a coarse group', () {
    expect(muscleMapHasContent(['Legs'], const []), isTrue);
    expect(muscleMapHasContent(const [], const []), isFalse);
  });

  test('catalog-supplied specific muscles drive the map and beat the name heuristic', () {
    // Name heuristic would say hamstring; the catalog says quadriceps — data must win.
    final inv = muscleMapInvolvement(
      'Lying Leg Curl',
      const ['Legs'],
      const [],
      detailedPrimary: const ['quadriceps'],
      detailedSecondary: const ['calves'],
    );
    expect(inv['quadriceps'], 2);
    expect(inv['calves'], 1);
    expect(inv['hamstring'], 0); // heuristic suppressed by the data
  });

  test('detailed muscles count toward hasContent even with no coarse names', () {
    expect(
      muscleMapHasContent(const [], const [], detailedPrimary: const ['biceps']),
      isTrue,
    );
  });
}
