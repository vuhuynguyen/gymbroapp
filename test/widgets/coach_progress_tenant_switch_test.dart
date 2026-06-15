import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/coach_models.dart';
import 'package:gymbroapp/data/models/progress_models.dart';
import 'package:gymbroapp/data/repositories/coach_progress_repository.dart';
import 'package:gymbroapp/features/coach/client_strength_screen.dart';
import 'package:gymbroapp/features/coach/coach_progress_screen.dart';
import 'package:gymbroapp/features/tenant/tenant_controller.dart';
import 'package:gymbroapp/shared/widgets/widgets.dart';

/// A fake coach-progress repo that records every read and returns canned, tenant-tagged data — no
/// network. Used to prove the Phase-2b providers refetch when the active gym switches.
class _FakeCoachProgressRepo implements CoachProgressRepository {
  _FakeCoachProgressRepo(this.tenantOf);

  /// Resolves the tenant id at call time so each refetch reflects the *current* active gym.
  final String? Function() tenantOf;

  int rosterCalls = 0;
  int strengthCalls = 0;
  int loadCalls = 0;
  final List<String?> rosterTenants = [];
  final List<String?> strengthTenants = [];
  final List<String?> loadTenants = [];

  @override
  Future<Roster> roster() async {
    rosterCalls++;
    final t = tenantOf();
    rosterTenants.add(t);
    return Roster(items: [
      ClientStatus(
        traineeId: 'c-$t',
        displayName: 'Client of $t',
        completedThisWeek: 1,
        weeklyGoal: 3,
        status: RosterStatus.quiet,
      ),
    ]);
  }

  @override
  Future<List<ExerciseE1rmSeries>> clientStrength(String traineeId, {int take = 6}) async {
    strengthCalls++;
    final t = tenantOf();
    strengthTenants.add(t);
    return [
      ExerciseE1rmSeries(
        exerciseId: 'ex-$t',
        exerciseName: 'Bench ($t)',
        points: const [],
        currentE1rmKg: 100,
        deltaKgVsTrailing4w: 0,
        direction: LiftTrendDirection.flat,
        stalled: false,
        stallSessions: 0,
      ),
    ];
  }

  @override
  Future<AcuteChronicLoad> clientLoad(String traineeId) async {
    loadCalls++;
    final t = tenantOf();
    loadTenants.add(t);
    return const AcuteChronicLoad(
      acuteVolumeKg: 9000,
      chronicWeeklyVolumeKg: 8000,
      trend: LoadTrend.steady,
    );
  }
}

/// The active-gym switch under test — a [StateProvider] that the overridden [activeTenantIdProvider]
/// reads, so flipping it triggers the exact refetch chain the real `TenantController` would.
final _activeTenant = StateProvider<String?>((ref) => 'gym-A');

void main() {
  late _FakeCoachProgressRepo repo;
  late ProviderContainer container;

  List<Override> overrides() => [
        activeTenantIdProvider.overrideWith((ref) => ref.watch(_activeTenant)),
        coachProgressRepositoryProvider.overrideWith((ref) => repo),
      ];

  Widget app(Widget home) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: home,
            ),
          ),
        ),
      );

  setUp(() {
    container = ProviderContainer(overrides: overrides());
    repo = _FakeCoachProgressRepo(() => container.read(_activeTenant));
  });

  tearDown(() => container.dispose());

  testWidgets('roster refetches (tenant-scoped) on a gym switch', (tester) async {
    await tester.pumpWidget(app(const CoachProgressScreen()));
    await tester.pumpAndSettle();

    expect(repo.rosterCalls, 1);
    expect(repo.rosterTenants, ['gym-A']);
    expect(find.text('Client of gym-A'), findsOneWidget);

    // Switch the active gym → the provider watches activeTenantIdProvider, so it refetches.
    container.read(_activeTenant.notifier).state = 'gym-B';
    await tester.pumpAndSettle();

    expect(repo.rosterCalls, 2);
    expect(repo.rosterTenants, ['gym-A', 'gym-B']);
    expect(find.text('Client of gym-B'), findsOneWidget);
    expect(find.text('Client of gym-A'), findsNothing);
  });

  testWidgets('per-client strength refetches (tenant-scoped) on a gym switch', (tester) async {
    await tester.pumpWidget(app(
      const ClientStrengthScreen(clientId: 'c1', clientName: 'Alice'),
    ));
    await tester.pumpAndSettle();

    expect(repo.strengthCalls, 1);
    expect(repo.strengthTenants, ['gym-A']);
    expect(find.text('Bench (gym-A)'), findsOneWidget);
    // The workload card on the same screen reads its own tenant-scoped provider on first load.
    expect(repo.loadCalls, 1);
    expect(repo.loadTenants, ['gym-A']);

    container.read(_activeTenant.notifier).state = 'gym-B';
    await tester.pumpAndSettle();

    expect(repo.strengthCalls, 2);
    expect(repo.strengthTenants, ['gym-A', 'gym-B']);
    expect(find.text('Bench (gym-B)'), findsOneWidget);
    // The workload provider watches activeTenantIdProvider too → it refetches on the gym switch.
    expect(repo.loadCalls, 2);
    expect(repo.loadTenants, ['gym-A', 'gym-B']);
  });

  testWidgets('no active tenant → roster returns empty WITHOUT a network read', (tester) async {
    container.read(_activeTenant.notifier).state = null;
    await tester.pumpWidget(app(const CoachProgressScreen()));
    await tester.pumpAndSettle();

    // The provider short-circuits to an empty roster and never calls the repo.
    expect(repo.rosterCalls, 0);
    expect(find.text('No clients yet'), findsOneWidget);
  });
}
