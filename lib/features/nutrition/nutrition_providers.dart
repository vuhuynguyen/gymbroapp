import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/nutrition_models.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../domain/enums.dart';
import '../tenant/tenant_controller.dart';

/// Today's nutrition log + the completion-first mutations. State is held locally so a tap updates the
/// checklist and adherence ring **immediately** (optimistic), with the network catching up. A failed
/// write rolls back — except a 404 (the nutrition surface isn't deployed yet), which we keep
/// optimistically, the same graceful degradation the repository's reads use.
class TodayNutritionController extends AsyncNotifier<DailyNutritionLog> {
  @override
  Future<DailyNutritionLog> build() =>
      ref.read(nutritionRepositoryProvider).today();

  NutritionRepository get _repo => ref.read(nutritionRepositoryProvider);

  /// Item writes are tenant-scoped (`/api/nutrition/log/*`, `X-Tenant-Id` from the active gym). The
  /// app resolves an active gym for every authenticated user with a membership, so this normally
  /// holds — but a user with no resolved workspace (e.g. memberships still empty) would 400. Guard up
  /// front so we surface a clear "select a gym" message and never fire an optimistic row we can't
  /// persist, rather than rolling back a raw validation error.
  String? get _tenantGuardError => ref.read(activeTenantIdProvider) == null
      ? 'Select a gym to log this item.'
      : null;

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.today);
  }

  /// Apply an optimistic transform, fire [write], roll back on a real failure (keep on 404).
  ///
  /// When [reconcile] is set, a *successful* write is followed by a silent refetch of the day so the
  /// locally-synthesised optimistic row (e.g. an off-plan add's `local-…` id) is replaced by the
  /// server-persisted item — with its real id and the server's roll-up counts. The refetch is
  /// best-effort: if it fails (e.g. transient network), we keep the optimistic state rather than
  /// surfacing an error for a write that already succeeded.
  Future<void> _optimistic(
    DailyNutritionLog Function(DailyNutritionLog) transform,
    Future<void> Function() write, {
    bool reconcile = false,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(transform(current));
    try {
      await write();
    } on ApiException catch (e) {
      if (e.isNotFound) return; // surface not deployed — keep the optimistic state
      state = AsyncData(current); // roll back, then surface to the caller
      rethrow;
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
    if (reconcile) {
      final fresh = await AsyncValue.guard(_repo.today);
      // Only adopt a real server day; on a refetch failure keep the optimistic state.
      if (fresh.hasValue) state = fresh;
    }
  }

  /// Row tap: complete a planned item, or un-complete it (the sacred one-tap loop).
  /// Ad-hoc items have no "planned" state — they were logged as eaten — and the server rejects it
  /// ("Status must be Completed or Skipped"), so they toggle completed ↔ skipped instead.
  Future<void> toggleComplete(NutritionItem item) {
    final NutritionItemStatus next;
    if (item.status == NutritionItemStatus.completed) {
      next = item.isAdhoc
          ? NutritionItemStatus.skipped
          : NutritionItemStatus.planned;
    } else {
      next = NutritionItemStatus.completed;
    }
    return setStatus(item, next);
  }

  /// The day key all writes are scoped to (the log being mutated).
  String? get _date => state.valueOrNull?.localDate;

  Future<void> setStatus(NutritionItem item, NutritionItemStatus status) {
    final date = _date;
    if (date == null) return Future.value();
    final guard = _tenantGuardError;
    if (guard != null) {
      return Future.error(ApiException(ApiErrorKind.validation, guard));
    }
    return _optimistic(
      (log) => log.withItem(item.id, (i) => i.copyWith(status: status)),
      () => _repo.setItemStatus(date: date, itemId: item.id, status: status),
    );
  }

  Future<void> swap(NutritionItem item, Food food, {num quantity = 1}) {
    final date = _date;
    if (date == null) return Future.value();
    final guard = _tenantGuardError;
    if (guard != null) {
      return Future.error(ApiException(ApiErrorKind.validation, guard));
    }
    return _optimistic(
      (log) => log.withItem(
        item.id,
        (i) => i.copyWith(
          status: NutritionItemStatus.substituted,
          foodId: food.id,
          foodName: food.name,
          kind: food.kind,
          swappedFromName: i.foodName,
          servingLabel: food.servingLabel ?? i.servingLabel,
          quantity: quantity,
          energyKcal: food.energyKcal,
          proteinG: food.proteinG,
          carbsG: food.carbsG,
          fatG: food.fatG,
          fiberG: food.fiberG,
        ),
      ),
      () => _repo.substitute(
          date: date, itemId: item.id, foodId: food.id, quantity: quantity),
    );
  }

  /// Log an off-plan food into [mealName] (or a synthetic "Off-plan" bucket when no meal matches).
  Future<void> addOffPlan(Food food, {String? mealName, num quantity = 1}) {
    final date = _date;
    if (date == null) return Future.value();
    final guard = _tenantGuardError;
    if (guard != null) {
      return Future.error(ApiException(ApiErrorKind.validation, guard));
    }
    // Local-only id for the optimistic row; the server assigns the real item id on reload.
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final item = NutritionItem(
      id: localId,
      isPlanned: false,
      foodId: food.id,
      foodName: food.name,
      status: NutritionItemStatus.completed,
      kind: food.kind,
      servingLabel: food.servingLabel,
      quantity: quantity,
      energyKcal: food.energyKcal,
      proteinG: food.proteinG,
      carbsG: food.carbsG,
      fatG: food.fatG,
      fiberG: food.fiberG,
      isCustom: food.isCustom,
    );
    return _optimistic(
      (log) {
        final target = mealName ?? (log.meals.isNotEmpty ? log.meals.last.name : 'Off-plan');
        final has = log.meals.any((m) => m.name == target);
        final meals = [
          for (final m in log.meals)
            if (m.name == target) m.copyWithItems([...m.items, item]) else m,
          if (!has) NutritionMeal(name: target, items: [item]),
        ];
        return log.copyWithMeals(meals);
      },
      () => _repo.addItem(
          date: date,
          food: food,
          mealName: mealName ?? 'Off-plan',
          quantity: quantity),
      reconcile: true,
    );
  }

  Future<void> removeItem(NutritionItem item) {
    final date = _date;
    if (date == null) return Future.value();
    final guard = _tenantGuardError;
    if (guard != null) {
      return Future.error(ApiException(ApiErrorKind.validation, guard));
    }
    return _optimistic(
      (log) => log.copyWithMeals([
        for (final m in log.meals)
          m.copyWithItems([for (final i in m.items) if (i.id != item.id) i]),
      ]),
      () => _repo.removeItem(date: date, itemId: item.id),
    );
  }
}

/// Today's log (self, cross-gym) + its optimistic mutations.
final todayNutritionProvider =
    AsyncNotifierProvider<TodayNutritionController, DailyNutritionLog>(
        TodayNutritionController.new);

/// The trainee's nutrition timeline (self, cross-gym) — the History link surface.
final nutritionHistoryProvider =
    FutureProvider.autoDispose<NutritionDayList>((ref) {
  return ref
      .read(nutritionRepositoryProvider)
      .myHistory(from: DateTime.now().subtract(const Duration(days: 56)));
});

/// One past day's read-only detail (self, cross-gym), keyed by `YYYY-MM-DD`.
final nutritionDayProvider =
    FutureProvider.autoDispose.family<DailyNutritionLog, String>(
  (ref, date) => ref.read(nutritionRepositoryProvider).day(date),
);

/// The day's body check-in (latest weight + sleep).
class CheckinController extends AsyncNotifier<DailyCheckin> {
  @override
  Future<DailyCheckin> build() => ref.read(nutritionRepositoryProvider).checkin();

  Future<void> _log(String type, num value, String unit, DailyCheckin next) async {
    final current = state.valueOrNull ?? DailyCheckin.empty;
    state = AsyncData(next);
    try {
      await ref.read(nutritionRepositoryProvider).logMetric(
            MetricEntry(type: type, value: value, unit: unit),
          );
    } on ApiException catch (e) {
      if (e.isNotFound) return; // surface not deployed — keep optimistic
      state = AsyncData(current);
      rethrow;
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> logWeight(num kg) => _log('weight', kg, 'kg',
      (state.valueOrNull ?? DailyCheckin.empty).copyWith(weightKg: kg));

  Future<void> logSleep(num hours) => _log('sleep', hours, 'h',
      (state.valueOrNull ?? DailyCheckin.empty).copyWith(sleepHours: hours));
}

final checkinProvider =
    AsyncNotifierProvider<CheckinController, DailyCheckin>(CheckinController.new);

/// Food-catalog search, keyed by (query, kind). Empty until the user types / picks a filter.
final foodSearchProvider = FutureProvider.autoDispose
    .family<FoodList, ({String search, FoodKind? kind})>((ref, q) {
  return ref
      .read(nutritionRepositoryProvider)
      .searchFoods(search: q.search, kind: q.kind);
});

// ── Coach (tenant-scoped) ─────────────────────────────────────────────────

/// A client's nutrition adherence timeline (coach monitor Nutrition segment).
final clientNutritionProvider =
    FutureProvider.autoDispose.family<NutritionDayList, String>((ref, clientId) {
  ref.watch(activeTenantIdProvider);
  return ref.read(nutritionRepositoryProvider).clientLogs(clientId,
      from: DateTime.now().subtract(const Duration(days: 28)));
});

/// One of a client's days (coach read-only detail), keyed by (clientId, date).
final clientNutritionDayProvider = FutureProvider.autoDispose
    .family<DailyNutritionLog, ({String clientId, String date})>((ref, a) {
  ref.watch(activeTenantIdProvider);
  return ref.read(nutritionRepositoryProvider).clientDay(a.clientId, a.date);
});
