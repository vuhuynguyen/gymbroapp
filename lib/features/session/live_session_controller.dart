import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session_metrics.dart';
import '../log/log_providers.dart';

class RestTimerState {
  const RestTimerState(this.remaining, this.total);
  final int remaining;
  final int total;
}

class LiveSessionState {
  const LiveSessionState({
    this.session,
    this.loading = true,
    this.errorMessage,
    this.currentExerciseId,
    this.elapsedSeconds = 0,
    this.rest,
    this.busy = false,
  });

  final ActiveSession? session;
  final bool loading;
  final String? errorMessage;
  final String? currentExerciseId;
  final int elapsedSeconds;
  final RestTimerState? rest;

  /// A mutation (log/edit/skip/substitute/add/complete/abandon) is in flight.
  final bool busy;

  List<PerformedExercise> get exercises => session?.exercises ?? const [];

  PerformedExercise? get currentExercise {
    final list = exercises;
    if (list.isEmpty) return null;
    for (final e in list) {
      if (e.id == currentExerciseId) return e;
    }
    return list.first;
  }

  LiveSessionState copyWith({
    ActiveSession? session,
    bool? loading,
    String? currentExerciseId,
    int? elapsedSeconds,
    bool? busy,
    bool clearError = false,
    String? errorMessage,
    RestTimerState? rest,
    bool clearRest = false,
  }) =>
      LiveSessionState(
        session: session ?? this.session,
        loading: loading ?? this.loading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        currentExerciseId: currentExerciseId ?? this.currentExerciseId,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        rest: clearRest ? null : (rest ?? this.rest),
        busy: busy ?? this.busy,
      );
}

/// Drives the full-screen Live Active Session. Screen-scoped (autoDispose): created on entering
/// `/session/...`, disposed on leaving — which cancels the ticker. Elapsed time is derived from
/// `startedAt`, so it stays correct across navigation. The server owns the state machine and the
/// single-active rule; this controller mirrors the Portal's optimistic in-place updates.
class LiveSessionController extends AutoDisposeNotifier<LiveSessionState> {
  Timer? _ticker;
  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  @override
  LiveSessionState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const LiveSessionState();
  }

  // ── Loading ────────────────────────────────────────────────────────────
  /// `id` may be the literal `active` (resume/just-started) or a session guid.
  Future<void> load(String id) async {
    state = const LiveSessionState();
    try {
      final ActiveSession? session;
      if (id == 'active') {
        session = await _repo.active();
      } else {
        final active = await _repo.active();
        session = (active != null && active.sessionId == id)
            ? active
            : ActiveSession.fromDetail(await _repo.detail(id));
      }
      if (session == null) {
        state = state.copyWith(
            loading: false, errorMessage: 'No active workout to resume.');
        return;
      }
      _applyLoaded(session);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.message);
    }
  }

  void _applyLoaded(ActiveSession session) {
    final firstIncomplete = session.exercises
        .where(
            (e) => !isPerformedExerciseComplete(e, _plannedCount(session, e)))
        .toList();
    state = LiveSessionState(
      session: session,
      loading: false,
      currentExerciseId: firstIncomplete.isNotEmpty
          ? firstIncomplete.first.id
          : (session.exercises.isNotEmpty ? session.exercises.first.id : null),
      elapsedSeconds: _elapsed(session),
    );
    if (session.status.isInProgress) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state.session;
      if (s == null) return;
      var next = state.copyWith(elapsedSeconds: _elapsed(s));
      final rest = state.rest;
      if (rest != null) {
        final remaining = rest.remaining - 1;
        next = remaining <= 0
            ? next.copyWith(clearRest: true)
            : next.copyWith(rest: RestTimerState(remaining, rest.total));
      }
      state = next;
    });
  }

  // ── Focus / rest ─────────────────────────────────────────────────────────
  void setCurrentExercise(String exerciseId) =>
      state = state.copyWith(currentExerciseId: exerciseId, clearRest: true);

  void adjustRest(int delta) {
    final r = state.rest;
    if (r == null) return;
    final remaining = (r.remaining + delta).clamp(0, 86400);
    state = state.copyWith(
        rest: RestTimerState(remaining, r.total + (delta > 0 ? delta : 0)));
  }

  void skipRest() => state = state.copyWith(clearRest: true);

  // ── Mutations ──────────────────────────────────────────────────────────
  Future<void> logSet(
    String exerciseId, {
    int? reps,
    double? weightKg,
    int? rpe,
    PerformedSetType? setType,
  }) async {
    final session = state.session;
    final ex = _findExercise(exerciseId);
    if (session == null || ex == null) return;

    final setNumber = ex.sets.length + 1;
    final snap = _snapshotFor(session, ex);
    final snapSet = (snap != null && snap.sets.length >= setNumber)
        ? snap.sets[setNumber - 1]
        : null;

    await _mutate(() async {
      final logged = await _repo.logSet(
        session.sessionId,
        ex.id,
        LogSetRequest(
          planSetId: snapSet?.planSetId,
          setNumber: setNumber,
          setType: setType ??
              (snapSet != null
                  ? PerformedSetType.parse(snapSet.setType.wire)
                  : PerformedSetType.working),
          reps: reps,
          weightKg: weightKg,
          rpe: rpe,
        ),
      );
      _replaceExercise(ex.id, ex.copyWith(sets: [...ex.sets, logged]));
      final plannedRest = snapSet?.restSeconds ?? 0;
      final restSeconds = plannedRest > 0 ? plannedRest : 90;
      state = state.copyWith(rest: RestTimerState(restSeconds, restSeconds));
    });
  }

  Future<void> editSet(
      String exerciseId, String setId, EditSetRequest body) async {
    final session = state.session;
    if (session == null) return;
    await _mutate(() async {
      await _repo.editSet(session.sessionId, exerciseId, setId, body);
      await _reload(session.sessionId);
    });
  }

  Future<void> deleteSet(String exerciseId, String setId) async {
    final session = state.session;
    final ex = _findExercise(exerciseId);
    if (session == null || ex == null) return;
    await _mutate(() async {
      await _repo.deleteSet(session.sessionId, exerciseId, setId);
      _replaceExercise(ex.id,
          ex.copyWith(sets: ex.sets.where((s) => s.id != setId).toList()));
    });
  }

  /// Whole-exercise skip. The API rejects (409) if the exercise has any logged set — guarded here
  /// for a clear message, but the server is the real boundary.
  Future<void> skipExercise(String exerciseId) async {
    final session = state.session;
    final ex = _findExercise(exerciseId);
    if (session == null || ex == null) return;
    if (ex.sets.isNotEmpty) {
      state = state.copyWith(
          errorMessage: 'Can’t skip — this exercise already has logged sets.');
      return;
    }
    await _mutate(() async {
      await _repo.updateExercise(
        session.sessionId,
        exerciseId,
        const UpdateExerciseRequest(action: ExerciseUpdateAction.skip),
      );
      await _reload(session.sessionId);
    });
  }

  /// Remove an exercise from the active session. There is no dedicated delete-exercise endpoint yet,
  /// so this clears any logged sets first (a prerequisite for skip) then skips it — which takes it out
  /// of the active flow. It is persisted as a skipped exercise.
  Future<void> removeExercise(String exerciseId) async {
    final session = state.session;
    final ex = _findExercise(exerciseId);
    if (session == null || ex == null) return;
    await _mutate(() async {
      // Full delete: the server removes the exercise and cascade-deletes its logged sets — distinct
      // from "skip", which keeps the exercise as a skipped record.
      await _repo.deleteExercise(session.sessionId, ex.id);
      await _reload(session.sessionId);
      // If focus was on the now-removed exercise, move it to the first remaining one.
      final remaining = state.session?.exercises ?? const [];
      if (remaining.isNotEmpty &&
          !remaining.any((e) => e.id == state.currentExerciseId)) {
        state = state.copyWith(
            currentExerciseId: remaining.first.id, clearRest: true);
      }
    });
  }

  Future<void> substituteExercise(
      String exerciseId, String substituteExerciseId) async {
    final session = state.session;
    if (session == null) return;
    await _mutate(() async {
      await _repo.updateExercise(
        session.sessionId,
        exerciseId,
        UpdateExerciseRequest(
          action: ExerciseUpdateAction.substitute,
          substituteExerciseId: substituteExerciseId,
        ),
      );
      await _reload(session.sessionId);
    });
  }

  Future<void> addExercise(String catalogExerciseId) async {
    final session = state.session;
    if (session == null) return;
    await _mutate(() async {
      final created = await _repo.addExercise(
        session.sessionId,
        AddExerciseRequest(
            exerciseId: catalogExerciseId, order: session.exercises.length + 1),
      );
      state = state.copyWith(
        session: session.copyWith(exercises: [...session.exercises, created]),
        currentExerciseId: created.id,
      );
    });
  }

  Future<bool> complete({int? rpeOverall}) async {
    final session = state.session;
    if (session == null) return false;
    final avg = averageCompletedRpe(session.exercises);
    final derivedRpe = rpeOverall ?? avg?.round().clamp(1, 10).toInt();
    final result = await _mutate(() async {
      await _repo.complete(
        session.sessionId,
        CompleteSessionRequest(
            rpeOverall: derivedRpe, completedAt: DateTime.now()),
      );
      _ticker?.cancel();
    });
    return result != null;
  }

  Future<bool> abandon() async {
    final session = state.session;
    if (session == null) return false;
    final result = await _mutate(() async {
      await _repo.abandon(session.sessionId);
      _ticker?.cancel();
    });
    return result != null;
  }

  // ── Internals ──────────────────────────────────────────────────────────
  /// Runs a mutation with a busy flag + error capture. Returns a non-null token on success.
  Future<Object?> _mutate(Future<void> Function() run) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await run();
      state = state.copyWith(busy: false);
      _invalidateLists();
      return const Object();
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, errorMessage: e.message);
      return null;
    }
  }

  Future<void> _reload(String sessionId) async {
    final active = await _repo.active();
    final session = (active != null && active.sessionId == sessionId)
        ? active
        : ActiveSession.fromDetail(await _repo.detail(sessionId));
    state = state.copyWith(session: session);
  }

  void _replaceExercise(String exerciseId, PerformedExercise updated) {
    final session = state.session;
    if (session == null) return;
    state = state.copyWith(
      session: session.copyWith(
        exercises: session.exercises
            .map((e) => e.id == exerciseId ? updated : e)
            .toList(),
      ),
    );
  }

  PerformedExercise? _findExercise(String id) {
    for (final e in state.exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _invalidateLists() {
    ref.invalidate(activeSessionProvider);
    ref.invalidate(sessionHistoryProvider);
  }

  static SessionSnapshotExercise? _snapshotFor(
      ActiveSession s, PerformedExercise ex) {
    final exs = s.snapshot?.exercises;
    if (exs == null) return null;
    for (final se in exs) {
      if (se.exerciseId == ex.exerciseId) return se;
    }
    return null;
  }

  static int? _plannedCount(ActiveSession s, PerformedExercise ex) =>
      _snapshotFor(s, ex)?.sets.length;

  static int _elapsed(ActiveSession s) {
    final start = s.startedAt;
    if (start == null) return 0;
    return computeElapsedSeconds(
      start.millisecondsSinceEpoch,
      DateTime.now().millisecondsSinceEpoch,
      0,
    );
  }
}

final liveSessionControllerProvider =
    AutoDisposeNotifierProvider<LiveSessionController, LiveSessionState>(
        LiveSessionController.new);
