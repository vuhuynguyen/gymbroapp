import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Regression tests for [GbStepper]'s direct-entry behavior:
///   • a typed value commits LIVE (on each keystroke), so a number typed right before tapping a button
///     like "Log set" is never lost to a missed focus-out commit;
///   • a comma decimal separator is accepted and normalised to a dot, so users on comma-locale devices
///     (whose numeric keyboard shows "," not ".") can still enter decimals.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  Future<void> beginEdit(WidgetTester tester) async {
    // Tap the displayed value ("0") to open the inline numeric field.
    await tester.tap(find.text('0'));
    await tester.pump();
  }

  testWidgets('a typed decimal value commits live (no focus-out needed)', (tester) async {
    num? changed;
    await tester.pumpWidget(host(GbStepper(
      value: 0,
      step: 2.5, // decimal stepper
      onChanged: (v) => changed = v,
    )));

    await beginEdit(tester);
    await tester.enterText(find.byType(TextField), '52.5');
    await tester.pump();

    // No unfocus / submit — the value is pushed on the keystroke itself.
    expect(changed, 52.5);
  });

  testWidgets('accepts a comma decimal separator and normalises it to a dot', (tester) async {
    num? changed;
    await tester.pumpWidget(host(GbStepper(
      value: 0,
      step: 0.5,
      onChanged: (v) => changed = v,
    )));

    await beginEdit(tester);
    // Comma-locale keyboards surface "," — it must not be filtered out, and must parse as 1.5.
    await tester.enterText(find.byType(TextField), '1,5');
    await tester.pump();

    expect(changed, 1.5);
  });

  testWidgets('an integer stepper still only accepts whole numbers', (tester) async {
    num? changed;
    await tester.pumpWidget(host(GbStepper(
      value: 0,
      step: 1, // integer stepper → no decimal separator allowed
      onChanged: (v) => changed = v,
    )));

    await beginEdit(tester);
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();

    expect(changed, 12);
  });
}
