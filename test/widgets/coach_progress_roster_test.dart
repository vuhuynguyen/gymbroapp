import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/coach_models.dart';
import 'package:gymbroapp/features/coach/coach_progress_screen.dart';
import 'package:gymbroapp/features/coach/coach_providers.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// Widget tests for the Phase-2b coach roster (COACH-VS-TRAINEE.md §2). Every test overrides
/// [coachRosterProvider] so nothing touches the network. We assert the four async states
/// (loading/error/empty/data), the status-chip colours, and the at-risk-first ordering.
void main() {
  ClientStatus client(
    String id,
    String name, {
    RosterStatus status = RosterStatus.onTrack,
    int done = 2,
    int? goal = 3,
    DateTime? lastActive,
  }) =>
      ClientStatus(
        traineeId: id,
        displayName: name,
        lastActiveAt: lastActive,
        completedThisWeek: done,
        weeklyGoal: goal,
        status: status,
      );

  Widget host(Override override) => ProviderScope(
        overrides: [override],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const CoachProgressScreen(),
            ),
          ),
        ),
      );

  Future<void> pumpRoster(WidgetTester tester, Roster data) async {
    await tester.pumpWidget(host(coachRosterProvider.overrideWith((ref) async => data)));
    await tester.pumpAndSettle();
  }

  testWidgets('loading → GbSkeletonList, no error', (tester) async {
    final completer = Completer<Roster>();
    await tester.pumpWidget(host(coachRosterProvider.overrideWith((ref) => completer.future)));
    await tester.pump(); // one frame — the future never resolves yet

    expect(find.byType(GbSkeletonList), findsOneWidget);
    expect(find.byType(ErrorRetry), findsNothing);

    completer.complete(const Roster(items: []));
    await tester.pumpAndSettle();
  });

  testWidgets('error → ErrorRetry with a Retry action', (tester) async {
    await tester.pumpWidget(
      host(coachRosterProvider.overrideWith((ref) async => throw Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(GbSkeletonList), findsNothing);
  });

  testWidgets('empty roster → "No clients yet" empty state', (tester) async {
    await pumpRoster(tester, const Roster(items: []));

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No clients yet'), findsOneWidget);
    expect(find.byType(ErrorRetry), findsNothing);
  });

  testWidgets('data → rows, the mandatory "this gym only" caption, status chips', (tester) async {
    await pumpRoster(
      tester,
      Roster(items: [
        client('c1', 'Alice', status: RosterStatus.onTrack),
        client('c2', 'Bob', status: RosterStatus.drifting),
        client('c3', 'Cara', status: RosterStatus.quiet),
      ]),
    );

    // The scope caption is present (coach sees own gym only).
    expect(find.text('This gym only'), findsOneWidget);

    // All three rows + each status chip label render.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Drifting'), findsOneWidget);
    expect(find.text('Quiet'), findsOneWidget);
  });

  testWidgets('status chip colours — Quiet amber, Drifting warning, On track success', (tester) async {
    await pumpRoster(
      tester,
      Roster(items: [
        client('c1', 'Alice', status: RosterStatus.onTrack),
        client('c2', 'Bob', status: RosterStatus.drifting),
        client('c3', 'Cara', status: RosterStatus.quiet),
      ]),
    );

    final gb = AppTheme.light().extension<GbColors>()!;

    GbStatusBadge badgeFor(String label) {
      final badge = find.ancestor(
        of: find.text(label),
        matching: find.byType(GbStatusBadge),
      );
      return tester.widget<GbStatusBadge>(badge);
    }

    expect(badgeFor('Quiet').foreground, gb.amberInk);
    expect(badgeFor('Quiet').background, gb.amberSoft);
    expect(badgeFor('Drifting').foreground, gb.warning300);
    expect(badgeFor('Drifting').background, gb.warning0);
    expect(badgeFor('On track').foreground, gb.success);
    expect(badgeFor('On track').background, gb.success0);
  });

  testWidgets('at-risk first — Quiet then Drifting then On track in render order', (tester) async {
    // Supplied On-track-first; the screen must reorder to at-risk-first.
    await pumpRoster(
      tester,
      Roster(items: [
        client('c1', 'OnTrackOne', status: RosterStatus.onTrack),
        client('c2', 'DriftingOne', status: RosterStatus.drifting),
        client('c3', 'QuietOne', status: RosterStatus.quiet),
      ]),
    );

    final quietY = tester.getTopLeft(find.text('QuietOne')).dy;
    final driftY = tester.getTopLeft(find.text('DriftingOne')).dy;
    final onTrackY = tester.getTopLeft(find.text('OnTrackOne')).dy;

    expect(quietY, lessThan(driftY)); // Quiet above Drifting
    expect(driftY, lessThan(onTrackY)); // Drifting above On track
  });

  testWidgets('within a status band, the most-stale (oldest last-active) leads', (tester) async {
    final now = DateTime.now();
    await pumpRoster(
      tester,
      Roster(items: [
        client('q1', 'QuietRecent',
            status: RosterStatus.quiet, lastActive: now.subtract(const Duration(days: 8))),
        client('q2', 'QuietStale',
            status: RosterStatus.quiet, lastActive: now.subtract(const Duration(days: 30))),
        client('q3', 'QuietNever', status: RosterStatus.quiet),
      ]),
    );

    final neverY = tester.getTopLeft(find.text('QuietNever')).dy; // null last-active = most stale
    final staleY = tester.getTopLeft(find.text('QuietStale')).dy;
    final recentY = tester.getTopLeft(find.text('QuietRecent')).dy;

    expect(neverY, lessThan(staleY));
    expect(staleY, lessThan(recentY));
    // The "never trained" client shows the honest no-session label.
    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('a client with no goal shows a raw count, not a fabricated ring denominator',
      (tester) async {
    await pumpRoster(
      tester,
      Roster(items: [
        client('c1', 'NoPlan', status: RosterStatus.onTrack, done: 1, goal: null),
      ]),
    );

    // "1" + "done" raw count present; no "/" ring fraction for the no-goal client.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
  });
}
