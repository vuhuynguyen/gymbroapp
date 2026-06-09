import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import '../log/log_providers.dart';

/// Shared "start a workout" flow used by the Log start sheet, the Plan tab, and the start picker.
/// Honors the single-active-session rule: a 409 means one is already running, so we resume the real
/// active session instead of starting a new one.
Future<void> startSession(
  BuildContext context,
  WidgetRef ref,
  StartSessionRequest request, {
  bool replace = false,
}) async {
  void navTo(String location) =>
      replace ? context.pushReplacement(location) : context.push(location);

  try {
    final res = await ref.read(sessionRepositoryProvider).start(request);
    ref.invalidate(activeSessionProvider);
    if (context.mounted) navTo('/session/${res.sessionId}');
  } on ApiException catch (e) {
    ref.invalidate(activeSessionProvider);
    if (!context.mounted) return;
    if (e.isConflict) {
      showInfoSnack(context, 'A workout is already in progress — resuming it.');
      try {
        final active = await ref.read(sessionRepositoryProvider).active();
        if (!context.mounted) return;
        if (active != null) {
          navTo('/session/${active.sessionId}');
        } else {
          context.go('/log');
        }
      } catch (_) {
        if (context.mounted) context.go('/log');
      }
    } else {
      showErrorSnack(context, e);
    }
  }
}

Future<void> startAdhoc(BuildContext context, WidgetRef ref, {bool replace = false}) => startSession(
      context,
      ref,
      StartSessionRequest(source: SessionSource.adhoc, clientTimezone: DateTime.now().timeZoneName),
      replace: replace,
    );

Future<void> startFromAssignment(
  BuildContext context,
  WidgetRef ref, {
  required String planAssignmentId,
  required String plannedWorkoutId,
  bool replace = false,
}) =>
    startSession(
      context,
      ref,
      StartSessionRequest(
        source: SessionSource.fromAssignment,
        planAssignmentId: planAssignmentId,
        plannedWorkoutId: plannedWorkoutId,
        clientTimezone: DateTime.now().timeZoneName,
      ),
      replace: replace,
    );
