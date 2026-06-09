import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../domain/enums.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/coach/assign_screen.dart';
import '../features/coach/client_monitor_screen.dart';
import '../features/coach/clients_screen.dart';
import '../features/coach/coach_plans_screen.dart';
import '../features/coach/plan_view_screen.dart';
import '../features/log/log_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/session/live_session_screen.dart';
import '../features/session/session_detail_screen.dart';
import '../features/session/start_session_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/tenant/join_workspace_screen.dart';
import '../features/tenant/workspace_picker_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

// Trainee-only shell roots an Owner is bounced off. `/log` is shared (an Owner self-trains there),
// so it is intentionally NOT here.
const _ownerForbidden = {'/plan', '/progress'};
const _coachRoots = {'/clients', '/coach-plans'};
// Coach-only full-screen routes — a resolved Client is bounced off these (the server also 403s).
const _coachOnlyPrefixes = ['/client/', '/assign/', '/plan-view/'];

/// go_router with a role-adaptive `StatefulShellRoute`. Branches (fixed order): log, plan, progress
/// (trainee), clients, coach-plans (coach), profile (shared). The redirect awaits the bootstrap
/// silent refresh (token gate) and routes a coach (Owner) to the coach shell, a trainee to the
/// trainee shell — re-running when the active role resolves/changes (refreshListenable).
final routerProvider = Provider<GoRouter>((ref) {
  final tokenStore = ref.read(tokenStoreProvider);
  final tenantStore = ref.read(tenantStoreProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    // Universal landing: everyone starts on /log (the workout log is the shared home tab). The role
    // guards below still bounce each role off the other's routes — also to /log.
    initialLocation: '/log',
    refreshListenable: Listenable.merge([tokenStore, tenantStore]),
    redirect: (context, state) {
      final authed = tokenStore.isAuthenticated;
      final loc = state.matchedLocation;
      final onAuthRoute = loc == '/login' || loc == '/forgot-password';

      if (!authed) return onAuthRoute ? null : '/login';
      if (onAuthRoute) return '/log';

      // Role-adaptive: keep each role on routes valid for it, bouncing to the shared /log home. /log +
      // /profile are shared (an Owner self-trains via Log) and /log is the default landing for both
      // roles. `main()` pre-resolves the role before the first frame; Owners still reach /clients,
      // /coach-plans etc. via the nav — they just start on Log.
      final role = tenantStore.activeRole;
      if (role == TenantRole.owner) {
        if (_ownerForbidden.contains(loc)) return '/log';
      } else if (role == TenantRole.client) {
        if (_coachRoots.contains(loc)) return '/log';
        if (_coachOnlyPrefixes.any(loc.startsWith)) return '/log';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),

      // Full-screen routes (no tab bar) — above the shell.
      GoRoute(
        path: '/session/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            LiveSessionScreen(sessionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/session-detail/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => SessionDetailScreen(
          sessionId: s.pathParameters['id']!,
          fromFinish: s.uri.queryParameters['finished'] == 'true',
          mine: s.uri.queryParameters['me'] == '1',
        ),
      ),
      GoRoute(
          path: '/start',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const StartSessionScreen()),
      GoRoute(
          path: '/join',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const JoinWorkspaceScreen()),
      GoRoute(
          path: '/workspaces',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const WorkspacePickerScreen()),

      // Coach full-screen routes.
      GoRoute(
        path: '/client/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ClientMonitorScreen(
          clientId: s.pathParameters['id']!,
          clientName: s.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/assign/:planId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AssignScreen(
          planId: s.pathParameters['planId']!,
          presetClientId: s.uri.queryParameters['clientId'],
        ),
      ),
      GoRoute(
        path: '/plan-view/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => PlanViewScreen(planId: s.pathParameters['id']!),
      ),

      // Role-adaptive bottom-tab shell.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/log', builder: (_, __) => const LogScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/plan', builder: (_, __) => const PlanScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/progress', builder: (_, __) => const ProgressScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/clients',
                builder: (_, __) => const CoachClientsScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/coach-plans',
                builder: (_, __) => const CoachPlansScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())
          ]),
        ],
      ),
    ],
  );
});
