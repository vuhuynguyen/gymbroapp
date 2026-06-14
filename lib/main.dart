import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'core/time/app_time_zone.dart';
import 'data/repositories/auth_repository.dart';
import 'features/tenant/tenant_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the IANA database and detect the device zone before anything formats a date or reports the zone.
  await AppTimeZone.init();

  final container = ProviderContainer();

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

  runApp(UncontrolledProviderScope(container: container, child: const GymBroApp()));
}
