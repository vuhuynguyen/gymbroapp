import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/nutrition_models.dart';
import 'package:gymbroapp/data/models/session_models.dart';
import 'package:gymbroapp/features/log/log_providers.dart';
import 'package:gymbroapp/features/log/log_screen.dart';
import 'package:gymbroapp/features/nutrition/nutrition_providers.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Log is now a Today | History segmented surface: Today is the daily-return checklist (workout hero
/// + nutrition), History is the session timeline.
class _NoPlanToday extends TodayNutritionController {
  @override
  Future<DailyNutritionLog> build() async => DailyNutritionLog.noPlan('2026-06-10');
}

void main() {
  Widget host() => ProviderScope(
        overrides: [
          activeSessionProvider.overrideWith((ref) async => null),
          sessionHistoryProvider.overrideWith(
              (ref) async => const SessionList(items: [], page: 1, pageSize: 50, totalCount: 0)),
          todayNutritionProvider.overrideWith(_NoPlanToday.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const LogScreen(),
            ),
          ),
        ),
      );

  testWidgets('Today shows the workout prompt + nutrition no-plan state', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Log'), findsOneWidget); // header
    expect(find.text('Start today’s workout'), findsOneWidget); // no active session
    expect(find.text('No nutrition plan yet'), findsOneWidget); // folded-in nutrition
  });

  testWidgets('switching to History shows the session timeline', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.text('No nutrition plan yet'), findsNothing); // Today content is gone
  });
}
