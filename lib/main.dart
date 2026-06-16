import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/notifications/nutrition_reminders.dart';
import 'core/providers.dart';
import 'core/time/app_time_zone.dart';
import 'data/repositories/auth_repository.dart';
import 'features/tenant/tenant_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the IANA database and detect the device zone before anything formats a date or reports the zone.
  await AppTimeZone.init();

  final container = ProviderContainer();

  // Build the router up front so a tapped notification can route through the same instance the app
  // renders (UncontrolledProviderScope below shares this container, so app.dart watches the same one).
  final router = container.read(routerProvider);

  // Initialize local reminders (best-effort; no-op where notifications are unsupported/denied). A tap
  // routes to the right screen — a meal reminder opens the Log tab, a rest alert reopens its session.
  await NutritionReminders.instance
      .init(onTap: (payload) => _routeNotification(router, payload));

  // Bootstrap before first frame: load the persisted active tenant, then attempt a silent refresh
  // against the secure-stored refresh cookie to restore the session (mirrors the Portal's
  // constructor silent-refresh + `auth.ready`). The router redirect then has correct auth state.
  await container.read(tenantStoreProvider).load();
  await container.read(authRepositoryProvider).restoreSession();

  // Pre-resolve the active workspace role so the FIRST router redirect is role-aware (avoids a flash
  // of the wrong shell, and closes the role-gate window for coach routes). Returns fast when not
  // authenticated (no network). Never fatal — the app still boots if tenant load fails.
  try {
    await container.read(tenantControllerProvider.future);
  } catch (_) {}

  // If a notification cold-launched the app (it was terminated), route to its target once the first
  // frame is mounted so go_router's redirect/initial-location has already settled.
  final launchPayload = await NutritionReminders.instance.launchPayload();

  runApp(UncontrolledProviderScope(container: container, child: const GymBroApp()));

  if (launchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routeNotification(router, launchPayload));
  }
}

/// Route a tapped notification's payload to the matching screen: `'log'` → the Log tab; `'session:<id>'`
/// → that live session. Unknown/empty payloads are ignored (the app just opens where it was).
void _routeNotification(GoRouter router, String? payload) {
  if (payload == null || payload.isEmpty) return;
  if (payload.startsWith('session:')) {
    final id = payload.substring('session:'.length);
    if (id.isNotEmpty) router.go('/session/$id');
    return;
  }
  if (payload == 'log') router.go('/log');
}
