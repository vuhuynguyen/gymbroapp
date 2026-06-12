import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/data/models/nutrition_models.dart';
import 'package:gymbroapp/domain/enums.dart';

void main() {
  NutritionItem item(String id, NutritionItemStatus status, {bool planned = true}) =>
      NutritionItem(
        id: id,
        isPlanned: planned,
        planMealItemId: planned ? 'p$id' : null,
        foodId: 'f$id',
        foodName: 'Food $id',
        status: status,
      );

  DailyNutritionLog log(List<NutritionItem> items) => DailyNutritionLog(
        id: 'd1',
        localDate: '2026-06-10',
        hasPlan: true,
        isClosed: false,
        source: SessionSource.fromAssignment,
        meals: [NutritionMeal(name: 'All', items: items)],
      );

  group('adherence rule (completed + substituted ÷ planned)', () {
    test('counts completed and substituted, ignores skipped/planned', () {
      final l = log([
        item('1', NutritionItemStatus.completed),
        item('2', NutritionItemStatus.substituted),
        item('3', NutritionItemStatus.skipped),
        item('4', NutritionItemStatus.planned),
      ]);
      expect(l.plannedCount, 4);
      expect(l.completedCount, 2);
      expect(l.adherencePct, 50);
    });

    test('ad-hoc items do not count toward the denominator', () {
      final l = log([
        item('1', NutritionItemStatus.completed),
        item('2', NutritionItemStatus.completed, planned: false), // ad-hoc
      ]);
      expect(l.plannedCount, 1);
      expect(l.adherencePct, 100);
    });

    test('a day with no planned items is 100%', () {
      expect(log([]).adherencePct, 100);
    });
  });

  group('optimistic withItem', () {
    test('replaces a single item by id, leaving others untouched', () {
      final l = log([
        item('1', NutritionItemStatus.planned),
        item('2', NutritionItemStatus.planned),
      ]);
      final next = l.withItem('1', (i) => i.copyWith(status: NutritionItemStatus.completed));
      expect(next.allItems.firstWhere((i) => i.id == '1').status, NutritionItemStatus.completed);
      expect(next.allItems.firstWhere((i) => i.id == '2').status, NutritionItemStatus.planned);
      expect(next.adherencePct, 50);
    });
  });

  group('parsing', () {
    test('tolerant enum parse + planned inferred from planMealItemId', () {
      final i = NutritionItem.fromJson({
        'id': 'i1',
        'planMealItemId': 'p1',
        'foodId': 'f1',
        'foodName': 'Oats',
        'status': 'substituted',
        'energyKcal': 320,
        'proteinG': 12,
      });
      expect(i.status, NutritionItemStatus.substituted);
      expect(i.isPlanned, isTrue);
      expect(i.isAdhoc, isFalse);
    });

    test('ad-hoc item (null planMealItemId) is not planned', () {
      final i = NutritionItem.fromJson(
          {'id': 'i2', 'foodId': 'f2', 'foodName': 'Banana', 'status': 'completed'});
      expect(i.isAdhoc, isTrue);
      expect(i.isPlanned, isFalse);
    });

    test('FoodKind tolerant parse', () {
      expect(FoodKind.parse('beverage'), FoodKind.beverage);
      expect(FoodKind.parse(2), FoodKind.supplement);
      expect(FoodKind.parse('Food'), FoodKind.food);
    });
  });

  group('Food.copyWith', () {
    const food = Food(
      id: 'f1',
      name: 'Oats',
      kind: FoodKind.food,
      brand: 'Acme',
      servingLabel: '1 cup',
      servingSizeGrams: 80,
      energyKcal: 300,
      proteinG: 10,
      carbsG: 54,
      fatG: 5,
      fiberG: 8,
      isCustom: true,
      isEdited: true,
      mine: true,
    );

    test('updates fiberG and servingSizeGrams', () {
      final updated = food.copyWith(fiberG: 12, servingSizeGrams: 100);
      expect(updated.fiberG, 12);
      expect(updated.servingSizeGrams, 100);
      // Other fields unchanged.
      expect(updated.id, 'f1');
      expect(updated.energyKcal, 300);
    });

    test('no-arg copyWith preserves all fields', () {
      final copy = food.copyWith();
      expect(copy.id, food.id);
      expect(copy.name, food.name);
      expect(copy.kind, food.kind);
      expect(copy.brand, food.brand);
      expect(copy.servingLabel, food.servingLabel);
      expect(copy.servingSizeGrams, food.servingSizeGrams);
      expect(copy.energyKcal, food.energyKcal);
      expect(copy.proteinG, food.proteinG);
      expect(copy.carbsG, food.carbsG);
      expect(copy.fatG, food.fatG);
      expect(copy.fiberG, food.fiberG);
      expect(copy.isCustom, food.isCustom);
      expect(copy.isEdited, food.isEdited);
      expect(copy.mine, food.mine);
    });
  });
}
