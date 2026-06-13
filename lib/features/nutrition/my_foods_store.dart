import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/secure_store.dart';
import '../../data/models/nutrition_models.dart';
import '../../domain/enums.dart';

/// Device-local "My foods" library — the trainee's saved customs + edited catalog variants.
///
/// Mirrors the design's localStorage model (`loadMyFoods`/`saveMyFood`/`deleteMyFood` in
/// data-nutrition.jsx): the API has no personal-foods endpoint, and the design is explicit that
/// these live "on this device — it won't change your gym's catalog". Persisted as one JSON array
/// under a single secure-storage key, capped at [_cap] entries.
class MyFoodsRepository {
  MyFoodsRepository(this._store);
  final SecureStore _store;

  static const _key = 'gbm_my_foods';
  static const _cap = 40;

  Future<List<Food>> load() async {
    final raw = await _store.read(_key);
    if (raw == null) {
      // First run: seed a couple so the manager isn't empty (matches the design demo seed).
      final seed = _seed();
      await _write(seed);
      return seed;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(Food.fromLocalJson)
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(List<Food> all) => _store.write(
      _key, jsonEncode(all.take(_cap).map((f) => f.toLocalJson()).toList()));

  /// Insert or update a saved food, deduped by id and by case-insensitive name, newest first.
  Future<List<Food>> save(List<Food> current, Food food) async {
    final entry = food.copyWith(mine: true);
    final rest = current.where((x) =>
        x.id != entry.id && x.name.toLowerCase() != entry.name.toLowerCase());
    final next = [entry, ...rest];
    await _write(next);
    return next.take(_cap).toList();
  }

  Future<List<Food>> delete(List<Food> current, String id) async {
    final next = current.where((x) => x.id != id).toList();
    await _write(next);
    return next;
  }

  List<Food> _seed() => const [
        Food(
          id: 'mfseed1',
          name: "Mum's protein lasagna",
          kind: FoodKind.food,
          servingLabel: '1 plate · 350 g',
          energyKcal: 540,
          proteinG: 42,
          carbsG: 48,
          fatG: 19,
          isCustom: true,
          mine: true,
        ),
        Food(
          id: 'mfseed2',
          name: 'Pre-workout shake',
          brand: 'IronFuel',
          kind: FoodKind.beverage,
          servingLabel: '1 scoop · 400 ml',
          energyKcal: 95,
          proteinG: 1,
          carbsG: 22,
          fatG: 0,
          isCustom: true,
          mine: true,
        ),
        Food(
          id: 'mfseed3',
          name: 'Whey protein (my brand)',
          brand: 'PeakLabs',
          kind: FoodKind.supplement,
          servingLabel: '1 scoop · 30 g',
          energyKcal: 112,
          proteinG: 25,
          carbsG: 2,
          fatG: 1,
          isEdited: true,
          mine: true,
        ),
      ];
}

final myFoodsRepositoryProvider = Provider<MyFoodsRepository>(
    (ref) => MyFoodsRepository(ref.read(secureStoreProvider)));

/// Live list of saved foods. UI reads this; mutations go through the notifier so both the picker
/// and the My-foods manager stay in sync from one source of truth.
final myFoodsProvider =
    AsyncNotifierProvider<MyFoodsController, List<Food>>(MyFoodsController.new);

class MyFoodsController extends AsyncNotifier<List<Food>> {
  MyFoodsRepository get _repo => ref.read(myFoodsRepositoryProvider);

  @override
  Future<List<Food>> build() => _repo.load();

  List<Food> get _current => state.valueOrNull ?? const [];

  /// Generate a stable local id for a newly-saved food (no catalog id).
  static String newId() =>
      'mf${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  Future<void> save(Food food) async {
    final next = await _repo.save(_current, food);
    state = AsyncData(next);
  }

  Future<void> delete(String id) async {
    final next = await _repo.delete(_current, id);
    state = AsyncData(next);
  }
}
