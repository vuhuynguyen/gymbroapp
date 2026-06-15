import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../domain/enums.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/coach/assign_screen.dart';
import '../features/coach/client_monitor_screen.dart';
import '../features/coach/client_strength_screen.dart';
import '../features/coach/coach_hub_screen.dart';
import '../features/coach/coach_progress_screen.dart';
import '../features/coach/plan_view_screen.dart';
import '../features/log/log_screen.dart';
import '../features/nutrition/my_foods_screen.dart';
import '../features/nutrition/nutrition_day_detail_screen.dart';
import '../features/nutrition/nutrition_history_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/lift_detail_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/session/live_session_screen.dart';
import '../features/session/session_detail_screen.dart';
import '../features/session/start_session_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/tenant/join_workspace_screen.dart';
import '../features/tenant/workspace_picker_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

// Trainee-only shell roots an Owner is bounced off. `/log` is shared (an Owner self-trains there)
// and `/progress` is now shared too (an Owner tracks their own trends), so neither is here.
const _ownerForbidden = {'/plan'};
const _coachRoots = {'/coach'};
// Coach-only full-screen routes — a resolved Client is bounced off these (the server also 403s).
const _coachOnlyPrefixes = [
  '/client/',
  '/assign/',
  '/plan-view/',
  '/coach-progress',
  '/coach-client/',
];

/// go_router with a role-adaptive `StatefulShellRoute`. Branches (fixed order): log, plan, progress,
/// coach (the coach hub), profile. The redirect awaits the bootstrap silent refresh (token gate) and
/// lands a coach (Owner) on the Coach hub, a trainee on Log — re-running when the active role
/// resolves/changes (refreshListenable).
final routerProvider = Provider<GoRouter>((ref) {
  final tokenStore = ref.read(tokenStoreProvider);
  final tenantStore = ref.read(tenantStoreProvider);

  // One-shot role landing: the first authed frame is sent to the role's home (Owner → /coach,
  // trainee → /log). After that, both roles navigate freely — an Owner can still open Log to self-
  // train and Progress for their own trends. Reset on sign-out so the next sign-in re-lands.
  var landed = false;

  return GoRouter(
    navigatorKey: _rootKey,
    // Universal initial location; the redirect re-homes an Owner to /coach on the first authed frame.
    initialLocation: '/log',
    refreshListenable: Listenable.merge([tokenStore, tenantStore]),
    redirect: (context, state) {
      final authed = tokenStore.isAuthenticated;
      final loc = state.matchedLocation;
      final onAuthRoute = loc == '/login' || loc == '/forgot-password';

      if (!authed) {
        landed = false;
        return onAuthRoute ? null : '/login';
      }

      final role = tenantStore.activeRole;
      final home = role == TenantRole.owner ? '/coach' : '/log';
      if (onAuthRoute) return home;

      // First authed frame: re-home an Owner sitting on the universal /log landing to their hub.
      // Guarded so an Owner who later taps Log isn't yanked back — landing fires exactly once.
      if (!landed && role != null) {
        landed = true;
        if (loc == '/log' && loc != home) return home;
      }

      // Role guards: keep each role off the other's routes, bouncing to the shared /log home. /log,
      // /progress and /profile are shared (an Owner self-trains and tracks their own trends).
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

      // Progress per-lift drill-down (full-screen, above the shell — tab bar hidden). Self-scoped;
      // both roles reach it for their own lifts (an Owner tracks their own trends, like /progress).
      GoRoute(
        path: '/progress/lift/:exerciseId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            LiftDetailScreen(exerciseId: s.pathParameters['exerciseId']!),
      ),

      // Nutrition full-screen routes (above the shell). Self-scoped for a trainee; the coach reaches a
      // client's day detail with a `clientId` query param (tenant-scoped read).
      GoRoute(
          path: '/nutrition-history',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const NutritionHistoryScreen()),
      GoRoute(
          path: '/my-foods',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const MyFoodsScreen()),
      GoRoute(
        path: '/nutrition-day/:date',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => NutritionDayDetailScreen(
          date: s.pathParameters['date']!,
          clientId: s.uri.queryParameters['clientId'],
          clientName: s.uri.queryParameters['name'],
        ),
      ),
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

      // Coach Progress surface (Phase 2b) — the at-risk-first roster and the per-client strength
      // detail. Tenant-scoped (own gym only); a resolved Client is bounced off (`_coachOnlyPrefixes`).
      GoRoute(
        path: '/coach-progress',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CoachProgressScreen(),
      ),
      GoRoute(
        path: '/coach-client/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ClientStrengthScreen(
          clientId: s.pathParameters['id']!,
          clientName: s.uri.queryParameters['name'],
        ),
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
          // The coach hub folds the client roster (/clients) and plan library (/coach-plans) into one
          // tab — those screens are now the hub's inner segments, not standalone shell branches.
          StatefulShellBranch(routes: [
            GoRoute(path: '/coach', builder: (_, __) => const CoachHubScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())
          ]),
        ],
      ),
    ],
  );
});
