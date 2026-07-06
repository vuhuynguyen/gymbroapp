import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Regression tests for the design system's "Definition of done" rules that this app must honor:
/// the a11y § ("icon-only buttons require a Semantics label; steppers announce value + unit") and
/// the Motion § ("respect reduced motion — drop the pulse/shimmer; show end states immediately").
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );

  group('accessibility — icon-only buttons carry a Semantics label', () {
    testWidgets('GbIconButton exposes its semanticLabel', (tester) async {
      await tester.pumpWidget(host(GbIconButton(icon: Icons.add, semanticLabel: 'Add set', onTap: () {})));
      expect(find.bySemanticsLabel('Add set'), findsOneWidget);
    });

    testWidgets('GbGlassButton exposes its semanticLabel', (tester) async {
      await tester
          .pumpWidget(host(GbGlassButton(icon: Icons.sports_score_rounded, semanticLabel: 'Finish or end workout', onTap: () {})));
      expect(find.bySemanticsLabel('Finish or end workout'), findsOneWidget);
    });
  });

  group('accessibility — stepper announces value + unit', () {
    testWidgets('GbStepper announces "name value unit" and labels its ± buttons', (tester) async {
      await tester.pumpWidget(host(
        GbStepper(value: 60, unit: 'kg', step: 2.5, semanticLabel: 'Weight', onChanged: (_) {}),
      ));
      expect(find.bySemanticsLabel('Weight 60 kg'), findsOneWidget);
      expect(find.bySemanticsLabel('Increase Weight'), findsOneWidget);
      expect(find.bySemanticsLabel('Decrease Weight'), findsOneWidget);
    });
  });

  group('motion — reduced motion shows steady end states (no infinite loop)', () {
    testWidgets('GbSkeleton settles under reduced motion', (tester) async {
      await tester.pumpWidget(host(const GbSkeleton(width: 120), reduceMotion: true));
      // Would hang/time out if the 1.1s shimmer kept repeating; settling proves it holds steady.
      await tester.pumpAndSettle();
      expect(find.byType(GbSkeleton), findsOneWidget);
    });
  });
}
