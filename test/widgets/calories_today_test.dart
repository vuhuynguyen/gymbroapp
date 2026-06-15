import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/features/nutrition/nutrition_widgets.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for [CaloriesTodayCard] — the honest "calories logged today" readout on Log's Today
/// surface. Two modes: a plan target shows "Logged Y / Target X kcal" with a progress bar; a
/// self-logger / no-plan day (targetKcal == null) shows "Logged Y kcal today" ONLY — no target, no
/// fabricated goal, no bar.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  /// All rendered text inside the card, concatenated (the Eyebrow label + the logged/target line).
  String cardText(WidgetTester tester) => tester
      .widgetList<RichText>(
        find.descendant(
          of: find.byType(CaloriesTodayCard),
          matching: find.byType(RichText),
        ),
      )
      .map((rt) => rt.text.toPlainText())
      .join(' | ');

  testWidgets('shows target + progress bar when targetKcal is present',
      (tester) async {
    await tester.pumpWidget(
      host(const CaloriesTodayCard(consumedKcal: 1800, targetKcal: 2200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CALORIES TODAY'), findsOneWidget); // Eyebrow upper-cases
    final text = cardText(tester);
    expect(text, contains('Logged 1800'));
    expect(text, contains('Target 2200 kcal'));
    expect(text, isNot(contains('kcal today'))); // target wording, not consumed-only

    // A progress bar is drawn against the target.
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('shows logged-only (no target, no bar) when targetKcal is null',
      (tester) async {
    await tester.pumpWidget(
      host(const CaloriesTodayCard(consumedKcal: 1950, targetKcal: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CALORIES TODAY'), findsOneWidget); // Eyebrow upper-cases
    final text = cardText(tester);
    expect(text, contains('Logged 1950'));
    expect(text, contains('kcal today'));
    // No target wording and no fabricated goal.
    expect(text, isNot(contains('Target')));
    // No progress bar / ring without a real target.
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.byType(GbRing), findsNothing);
  });
}
