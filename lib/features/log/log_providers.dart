import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/session_models.dart';
import '../../data/repositories/session_repository.dart';
import '../../shared/paging/paged.dart';
import '../tenant/tenant_controller.dart';

/// The single resumable in-progress session (null when none) — drives the Log hero.
/// `GET /sessions/active` is **self-scoped** (no X-Tenant-Id), so resume must NOT be gated on an
/// active tenant. Refreshed by pull-to-refresh and after live-session mutations.
final activeSessionProvider = FutureProvider.autoDispose<ActiveSession?>(
  (ref) => ref.read(sessionRepositoryProvider).active(),
);

/// The trainee's Workout Log history — the **unified personal** timeline across every gym they belong to
/// (`GET /api/me/sessions`, self-scoped), paged with infinite scroll. The Log screen accumulates pages and
/// groups them by week client-side.
class SessionHistoryNotifier extends PagedNotifier<SessionSummary> {
  @override
  int get pageSize => 20;

  @override
  Future<PageResult<SessionSummary>> fetch(int page, int pageSize) async {
    final r = await ref
        .read(sessionRepositoryProvider)
        .myHistory(page: page, pageSize: pageSize);
    return PageResult(r.items, r.totalCount);
  }
}

final sessionHistoryProvider = AutoDisposeNotifierProvider<
    SessionHistoryNotifier,
    AsyncValue<PagedData<SessionSummary>>>(SessionHistoryNotifier.new);

/// The trainee's own session detail (cross-gym, `GET /api/me/sessions/{id}`). Used by the Log and
/// the just-finished screen.
final mySessionDetailProvider =
    FutureProvider.autoDispose.family<SessionDetail, String>(
  (ref, sessionId) => ref.read(sessionRepositoryProvider).myDetail(sessionId),
);

/// A session's detail scoped to the active gym (`GET /api/sessions/{id}`). Used by the COACH client
/// monitor (WorkoutLogViewAll) to open a client's session.
final sessionDetailProvider =
    FutureProvider.autoDispose.family<SessionDetail, String>((ref, sessionId) {
  ref.watch(activeTenantIdProvider);
  return ref.read(sessionRepositoryProvider).detail(sessionId);
});
