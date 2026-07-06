import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/session_models.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/enums.dart';
import '../../domain/session_metrics.dart';
import '../../core/notifications/nutrition_reminders.dart';
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
    this.setTargets = const {},
  });

  final ActiveSession? session;
  final bool loading;
  final String? errorMessage;
  final String? currentExerciseId;
  final int elapsedSeconds;
  final RestTimerState? rest;

  /// A mutation (log/edit/skip/substitute/add/complete/abandon) is in flight.
  final bool busy;

  /// Per-exercise target set count (performed-exercise id → count). Starts at the plan's prescribed
  /// count; the user adjusts it — deleting a set lowers it (so the set stays gone instead of re-showing
  /// as a planned placeholder), logging beyond it raises it. Kept in state so it survives a reload.
  final Map<String, int> setTargets;

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
    Map<String, int>? setTargets,
  }) =>
      LiveSessionState(
        session: session ?? this.session,
        loading: loading ?? this.loading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        currentExerciseId: currentExerciseId ?? this.currentExerciseId,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        rest: clearRest ? null : (rest ?? this.rest),
        busy: busy ?? this.busy,
        setTargets: setTargets ?? this.setTargets,
      );
}

/// Drives the full-screen Live Active Session. Screen-scoped (autoDispose): created on entering
/// `/session/...`, disposed on leaving — which cancels the ticker. Elapsed time is derived from
/// `startedAt`, so it stays correct across navigation. The server owns the state machine and the
/// single-active rule; this controller mirrors the Portal's optimistic in-place updates.
class LiveSessionController extends AutoDisposeNotifier<LiveSessionState> {
  Timer? _ticker;

  /// Wall-clock moment the current rest began; used to auto-capture the actual rest taken on the next set.
  DateTime? _restStartedAt;
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
        if (remaining <= 0) {
          // Foreground countdown finished — the user is here, so cancel the duplicate OS alert.
          unawaited(NutritionReminders.instance.cancelRestDone());
          next = next.copyWith(clearRest: true);
        } else {
          next = next.copyWith(rest: RestTimerState(remaining, rest.total));
        }
      }
      state = next;
    });
  }

  // ── Focus / rest ─────────────────────────────────────────────────────────
  void setCurrentExercise(String exerciseId) {
    unawaited(NutritionReminders.instance.cancelRestDone());
    state = state.copyWith(currentExerciseId: exerciseId, clearRest: true);
  }

  void adjustRest(int delta) {
    final r = state.rest;
    if (r == null) return;
    final remaining = (r.remaining + delta).clamp(0, 86400);
    state = state.copyWith(
        rest: RestTimerState(remaining, r.total + (delta > 0 ? delta : 0)));
    // Keep the OS alert in step with the adjusted countdown.
    unawaited(NutritionReminders.instance
        .scheduleRestDone(remaining, sessionId: state.session?.sessionId));
  }

  void skipRest() {
    unawaited(NutritionReminders.instance.cancelRestDone());
    state = state.copyWith(clearRest: true);
  }

  // ── Mutations ──────────────────────────────────────────────────────────
  Future<void> logSet(
    String exerciseId, {
    int? reps,
    double? weightKg,
    int? rpe,
    PerformedSetType? setType,
    int? durationSeconds,
    int? distanceM,
    int? calories,
    int? avgHeartRate,
    int? rounds,
    double? inclinePercent,
    double? speedKph,
    int? level,
    int? restSeconds,
    String? parentSetId,
  }) async {
    final session = state.session;
    final ex = _findExercise(exerciseId);
    if (session == null || ex == null) return;

    final setNumber = ex.sets.length + 1;
    final snap = _snapshotFor(session, ex);

    // The picked set type wins; otherwise an explicit parent implies a Drop, else continue the plan's
    // prescribed type (default Working).
    final resolvedType = setType ??
        (parentSetId != null
            ? PerformedSetType.drop
            : ((snap != null && snap.sets.length >= setNumber)
                ? PerformedSetType.parse(snap.sets[setNumber - 1].setType.wire)
                : PerformedSetType.working));

    // A Drop or Cluster set auto-links to the last lead set, so the stages roll up as ONE logical set —
    // the user just picks "Drop"/"Cluster" from the set-type selector (no separate "add stage" action).
    var linkParent = parentSetId;
    if (linkParent == null &&
        (resolvedType == PerformedSetType.drop ||
            resolvedType == PerformedSetType.cluster)) {
      final leads = ex.sets.where((s) => s.parentSetId == null).toList();
      if (leads.isNotEmpty) linkParent = leads.last.id;
    }
    final isDropStage = linkParent != null;

    // A drop stage continues the lead set, so it doesn't pull from the plan's next prescribed set.
    final snapSet =
        (!isDropStage && snap != null && snap.sets.length >= setNumber)
            ? snap.sets[setNumber - 1]
            : null;

    // Rest is logged only on a lead set; a passed value overrides the auto-captured actual rest taken.
    final effectiveRest = isDropStage
        ? null
        : (restSeconds ??
            (_restStartedAt != null
                ? DateTime.now().difference(_restStartedAt!).inSeconds
                : null));

    await _mutate(() async {
      final logged = await _repo.logSet(
        session.sessionId,
        ex.id,
        LogSetRequest(
          planSetId: snapSet?.planSetId,
          parentSetId: linkParent,
          setNumber: setNumber,
          setType: resolvedType,
          reps: reps,
          weightKg: weightKg,
          rpe: rpe,
          durationSeconds: durationSeconds,
          distanceM: distanceM,
          calories: calories,
          avgHeartRate: avgHeartRate,
          rounds: rounds,
          inclinePercent: inclinePercent,
          speedKph: speedKph,
          level: level,
          restSeconds: effectiveRest,
        ),
      );
      _replaceExercise(ex.id, ex.copyWith(sets: [...ex.sets, logged]));
      // Logging beyond the current target raises it, so the prescription preview + "X/Y" keep up.
      final planned = snap?.sets.length ?? 0;
      final newCount = ex.sets.length + 1;
      if (newCount > (state.setTargets[ex.id] ?? planned)) {
        state =
            state.copyWith(setTargets: {...state.setTargets, ex.id: newCount});
      }
      _restStartedAt = null;
      if (isDropStage)
        return; // drop stage: no rest timer, no superset rotation
      _advanceAfterSet(ex, snapSet?.restSeconds ?? 0);
    });
  }

  /// Exercises performed together as a superset (same group id), ordered; just [ex] when standalone.
  List<PerformedExercise> _supersetPeers(PerformedExercise ex) {
    final session = state.session;
    if (session == null || ex.supersetGroupId == null) return [ex];
    return session.exercises
        .where((e) => e.supersetGroupId == ex.supersetGroupId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Superset-aware progression: rotate to the next peer; rest only after the round wraps to the first peer.
  void _advanceAfterSet(PerformedExercise ex, int plannedRest) {
    final rest = plannedRest > 0 ? plannedRest : 90;
    // Editing a finished workout: no rest timer (the ticker doesn't run on a completed session), just
    // advance the superset focus so a stale rest bar never appears.
    final editing = !isEditableLive;
    final peers = _supersetPeers(ex);
    if (peers.length > 1) {
      final idx = peers.indexWhere((p) => p.id == ex.id);
      final next = peers[(idx + 1) % peers.length];
      if (!editing && next.id == peers.first.id) {
        // Round complete → rest, then resume on the first peer.
        _restStartedAt = DateTime.now();
        state = state.copyWith(
            currentExerciseId: next.id, rest: RestTimerState(rest, rest));
        unawaited(NutritionReminders.instance
            .scheduleRestDone(rest, sessionId: state.session?.sessionId));
      } else {
        // Mid-round (or editing) → straight to the next peer, no rest.
        unawaited(NutritionReminders.instance.cancelRestDone());
        state = state.copyWith(currentExerciseId: next.id, clearRest: true);
      }
      return;
    }
    if (editing) {
      state = state.copyWith(clearRest: true);
      return;
    }
    _restStartedAt = DateTime.now();
    state = state.copyWith(rest: RestTimerState(rest, rest));
    // Fire a "rest's over" OS alert at rest-end so it reaches the user even if the app is backgrounded.
    unawaited(NutritionReminders.instance
        .scheduleRestDone(rest, sessionId: state.session?.sessionId));
  }

  /// True while a live (in-progress) session is loaded — drives the rest timer & finish CTA. False when
  /// editing a finished workout in place (status != InProgress).
  bool get isEditableLive => state.session?.status.isInProgress ?? false;

  /// True when the loaded session is a finished workout being edited in place (not the live workout).
  bool get isEditingFinished {
    final s = state.session;
    return s != null && !s.status.isInProgress;
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

  /// Reorders a logged lead set one slot up ([up] = true) or down, carrying its drop-stage cluster with
  /// it. Sends the full new set-id order to the server (which renumbers), and reorders state optimistically.
  Future<void> moveSet(String exerciseId, String setId,
      {required bool up}) async {
    final session = state.session;
    final ex = _findExercise(exerciseId);
    if (session == null || ex == null) return;
    final sets = ex.sets;
    final leads = sets.where((s) => s.parentSetId == null).toList();
    final idx = leads.indexWhere((s) => s.id == setId);
    final target = up ? idx - 1 : idx + 1;
    if (idx < 0 || target < 0 || target >= leads.length) return;
    final moved = leads[idx];
    final newLeads = [...leads]
      ..removeAt(idx)
      ..insert(target, moved);
    // Flatten each lead with its drop stages so a cluster moves as one unit.
    final ordered = <PerformedSet>[
      for (final lead in newLeads) ...[
        lead,
        ...sets.where((s) => s.parentSetId == lead.id),
      ],
    ];
    await _mutate(() async {
      await _repo.reorderSets(
          session.sessionId, exerciseId, ordered.map((s) => s.id).toList());
      _replaceExercise(ex.id, ex.copyWith(sets: ordered));
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
      // Lower the target so the deleted set stays gone (no planned placeholder re-fills its slot) and the
      // count drops — but never below the sets still logged.
      final planned = _snapshotFor(session, ex)?.sets.length ?? 0;
      final remaining = ex.sets.length - 1;
      final lowered = (state.setTargets[ex.id] ?? planned) - 1;
      state = state.copyWith(setTargets: {
        ...state.setTargets,
        ex.id: lowered < remaining ? remaining : lowered,
      });
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

  /// Toggle the superset link between [exerciseId] and the exercise directly before it (by order).
  /// [link] true pairs them into a rotation (they share/start a group id); false leaves the superset.
  /// Linking the first exercise is a no-op — there's nothing before it to pair with.
  Future<void> setSupersetWithPrevious(String exerciseId,
      {required bool link}) async {
    final session = state.session;
    if (session == null) return;
    String? peerId;
    if (link) {
      final ordered = [...session.exercises]
        ..sort((a, b) => a.order.compareTo(b.order));
      final idx = ordered.indexWhere((e) => e.id == exerciseId);
      if (idx <= 0) return; // not found, or first exercise → no previous peer
      peerId = ordered[idx - 1].id;
    }
    await _mutate(() async {
      await _repo.setExerciseSuperset(session.sessionId, exerciseId,
          peerExerciseId: peerId);
      await _reload(session.sessionId);
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
      unawaited(NutritionReminders.instance.cancelRestDone());
    });
    return result != null;
  }

  Future<bool> abandon() async {
    final session = state.session;
    if (session == null) return false;
    final result = await _mutate(() async {
      await _repo.abandon(session.sessionId);
      _ticker?.cancel();
      unawaited(NutritionReminders.instance.cancelRestDone());
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

  /// Leaving the edit-a-finished-workout flow: edits already saved per-mutation, so just refresh the
  /// history list and this session's detail so the corrected data shows on the screens behind.
  void doneEditing() {
    final id = state.session?.sessionId;
    ref.invalidate(sessionHistoryProvider);
    if (id != null) {
      ref.invalidate(mySessionDetailProvider(id));
      ref.invalidate(sessionDetailProvider(id));
    }
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
