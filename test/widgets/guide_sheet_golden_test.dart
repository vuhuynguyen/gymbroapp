import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/core/theme/app_colors.dart';
import 'package:gymbroapp/data/models/exercise_models.dart';
import 'package:gymbroapp/features/session/live_session_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the Form Coach guide sheet to golden PNGs so its styling can be eyeballed without the API.
/// Two fixtures: an authored exercise (Barbell Bench Press — full rich guide) and a cardio exercise
/// resolved purely from API data (Assault Bike — steps + safety, no authored setup/cues).
void main() {
  // Authored library exercise: API gives muscles + difficulty + instructions; the guide library
  // fills tempo/breathing/setup/cues/safety.
  const bench = ExerciseDetail(
    id: 'b1',
    name: 'Barbell Bench Press',
    difficulty: 'Intermediate',
    equipment: 'Barbell + flat bench',
    muscleGroup: 'Chest',
    instructions: [
      'Unrack and hold the bar locked out over your chest',
      'Lower under control to your mid-chest / nipple line',
      'Touch lightly — never bounce the bar',
      'Press up and slightly back toward your face to lockout',
    ],
    muscles: [
      ExerciseMuscle(name: 'Chest', isPrimary: true),
      ExerciseMuscle(name: 'Triceps', isPrimary: false),
      ExerciseMuscle(name: 'Front delts', isPrimary: false),
    ],
    warnings: [],
    media: [],
  );

  // Cardio, not in the authored library: steps from API instructions, warning → safety callout,
  // no setup/cues/tempo/breathing.
  const assaultBike = ExerciseDetail(
    id: 'a1',
    name: 'Assault Bike / Air Bike',
    difficulty: 'Intermediate',
    equipment: 'Machine',
    muscleGroup: 'Legs',
    instructions: [
      'Drive the arms and legs together for a smooth, continuous rhythm.',
      'Adjust the pace for steady-state work or hard intervals.',
    ],
    muscles: [
      ExerciseMuscle(name: 'Legs', isPrimary: true),
      ExerciseMuscle(name: 'Arms', isPrimary: false),
      ExerciseMuscle(name: 'Core', isPrimary: false),
    ],
    warnings: [
      'Ease into the first minute; air resistance scales hard with effort.',
    ],
    media: [],
  );

  Widget host(ExerciseDetail detail) => MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const [GbColors.light],
        ),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: buildGuideSheetForTest(
              detail: Future.value(detail),
              exerciseName: detail.name,
            ),
          ),
        ),
      );

  Future<void> pumpSized(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  for (final tab in ['Steps', 'Setup', 'Cues', 'Mistakes']) {
    testWidgets('bench (authored) — $tab tab', (tester) async {
      await pumpSized(tester, host(bench));
      if (tab != 'Steps') {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/guide_bench_${tab.toLowerCase()}.png'),
      );
    });
  }

  testWidgets('form-cue strip — inset rounded bar', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 120 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: const [GbColors.light]),
      home: Scaffold(
        backgroundColor: const Color(0xFFEFF2F6),
        body: Center(
          child: buildFormCueStripForTest(
            catalog: const ExerciseSummary(
              id: 'a1',
              name: 'Assault Bike / Air Bike',
              type: 'Cardio',
              movementType: 'Machine',
              difficulty: 'Intermediate',
              equipment: 'Machine',
              muscleGroup: 'Legs',
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/form_cue_strip.png'),
    );
  });

  testWidgets('preview variant — eyebrow + footer, single handle', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: const [GbColors.light]),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: buildGuideSheetForTest(
            detail: Future.value(bench),
            exerciseName: bench.name,
            eyebrow: 'PREVIEW · BEFORE ADDING',
            footer: Row(
              children: [
                OutlinedButton(onPressed: () {}, child: const Text('Back')),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                      onPressed: () {}, child: const Text('Add to session')),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/guide_preview.png'),
    );
  });

  // Regression: the catalog seeds ImageUrl as an EMPTY string (not null). A loaded exercise with imageUrl == ""
  // must still render the muscle map — not flash it during loading then fall back to Image.network("") + placeholder.
  testWidgets('empty imageUrl ("") still renders the muscle map', (tester) async {
    const benchNoImage = ExerciseDetail(
      id: 'b1',
      name: 'Barbell Bench Press',
      difficulty: 'Intermediate',
      equipment: 'Barbell',
      muscleGroup: 'Chest',
      imageUrl: '',
      instructions: ['Press the bar to lockout'],
      muscles: [ExerciseMuscle(name: 'Chest', isPrimary: true)],
      warnings: [],
      media: [],
    );
    await pumpSized(tester, host(benchNoImage));
    expect(find.byType(SvgPicture), findsWidgets);
  });

  testWidgets('assault bike (API-derived) — Steps tab', (tester) async {
    await pumpSized(tester, host(assaultBike));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/guide_assault_steps.png'),
    );
  });

  testWidgets('assault bike (API-derived) — Setup tab (empty)', (tester) async {
    await pumpSized(tester, host(assaultBike));
    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/guide_assault_setup.png'),
    );
  });

  testWidgets('assault bike (API-derived) — Mistakes tab (safety)', (tester) async {
    await pumpSized(tester, host(assaultBike));
    await tester.tap(find.text('Mistakes'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/guide_assault_mistakes.png'),
    );
  });
}
