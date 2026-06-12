import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/plan_models.dart';
import 'package:gymbroapp/features/coach/clients_screen.dart';
import 'package:gymbroapp/features/coach/coach_hub_screen.dart';
import 'package:gymbroapp/features/coach/coach_providers.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// The Coach hub folds the roster (Clients) and the plan library (Plans) into one tab, with the
/// Invite action scoped to the Clients segment. Switching segments swaps the embedded body.
void main() {
  Widget host() => ProviderScope(
        overrides: [
          // Empty data so neither child hits the network (and no tenant/secure-storage touch).
          coachClientsProvider.overrideWith((ref) async => []),
          coachPlansProvider.overrideWith((ref) async =>
              const WorkoutPlanList(items: [], page: 1, pageSize: 200, totalCount: 0)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const CoachHubScreen(),
            ),
          ),
        ),
      );

  testWidgets('starts on Clients with the Invite action; shows the roster body', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Coach'), findsOneWidget); // header title
    expect(find.text('Invite'), findsOneWidget); // Clients-only action
    expect(find.text('No clients yet'), findsOneWidget); // embedded ClientsScreen body
    expect(find.byType(CoachClientsScreen), findsOneWidget);
  });

  testWidgets('switching to Plans swaps the body and hides Invite', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();

    expect(find.text('No plans yet'), findsOneWidget); // embedded PlansScreen body
    expect(find.text('Invite'), findsNothing); // Invite is Clients-only
  });
}
