import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbroapp/core/providers.dart';
import 'package:gymbroapp/core/storage/secure_store.dart';
import 'package:gymbroapp/core/theme/app_colors.dart';
import 'package:gymbroapp/data/models/nutrition_models.dart';
import 'package:gymbroapp/domain/enums.dart';
import 'package:gymbroapp/features/nutrition/custom_food_form.dart';
import 'package:gymbroapp/features/nutrition/food_picker_sheet.dart';
import 'package:gymbroapp/features/nutrition/my_foods_screen.dart';
import 'package:gymbroapp/features/nutrition/nutrition_providers.dart';

/// Visual checks for the nutrition food feature: My Foods manager (seeded + empty), the custom-food
/// form, and the food picker (search results + confirm step). Renders to golden PNGs so the styling
/// can be eyeballed without the API / device storage.
class _FakeSecureStore implements SecureStore {
  _FakeSecureStore(this._data);
  final Map<String, String> _data;
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

const _seededMyFoods = [
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

const _catalog = FoodList(items: [
  Food(id: 'f1', name: 'Chicken breast, grilled', kind: FoodKind.food, servingLabel: '100 g', energyKcal: 165, proteinG: 31, carbsG: 0, fatG: 4),
  Food(id: 'f3', name: 'Whey protein', brand: 'IronFuel', kind: FoodKind.supplement, servingLabel: '1 scoop · 30 g', energyKcal: 120, proteinG: 24, carbsG: 3, fatG: 2),
  Food(id: 'f8', name: 'Flat white', kind: FoodKind.beverage, servingLabel: '1 cup', energyKcal: 90, proteinG: 5, carbsG: 7, fatG: 5),
  Food(id: 'f9', name: 'Salmon fillet, baked', kind: FoodKind.food, servingLabel: '140 g', energyKcal: 280, proteinG: 30, carbsG: 0, fatG: 17),
], totalCount: 4);

ThemeData _theme() => ThemeData(useMaterial3: true, extensions: const [GbColors.light]);

Future<void> _pump(WidgetTester tester, Widget child,
    {List<Food> myFoods = const [], Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = _FakeSecureStore({
    if (myFoods.isNotEmpty)
      'gbm_my_foods': jsonEncode([for (final f in myFoods) f.toLocalJson()])
    else
      'gbm_my_foods': '[]',
  });

  await tester.pumpWidget(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      foodSearchProvider.overrideWith((ref, q) async => _catalog),
    ],
    child: MaterialApp(theme: _theme(), home: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('My Foods manager — seeded (custom + edited sections)', (tester) async {
    await _pump(tester, const MyFoodsScreen(), myFoods: _seededMyFoods);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/my_foods_seeded.png'));
  });

  testWidgets('My Foods manager — empty state', (tester) async {
    await _pump(tester, const MyFoodsScreen());
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/my_foods_empty.png'));
  });

  testWidgets('Custom food form', (tester) async {
    await _pump(
      tester,
      Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: CustomFoodForm(
              submitLabel: 'Save food',
              submitIcon: Icons.check,
              onContinue: (_) {},
            ),
          ),
        ),
      ),
    );
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/custom_food_form.png'));
  });

  testWidgets('Food picker — search results', (tester) async {
    await _pump(
      tester,
      Scaffold(
        backgroundColor: Colors.white,
        body: buildFoodPickerForTest(
            swap: false, meals: const ['Breakfast', 'Lunch', 'Snack', 'Dinner']),
      ),
      myFoods: _seededMyFoods,
    );
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/food_picker_search.png'));
  });

  testWidgets('Food picker — confirm step', (tester) async {
    await _pump(
      tester,
      Scaffold(
        backgroundColor: Colors.white,
        body: buildFoodPickerForTest(
            swap: false, meals: const ['Breakfast', 'Lunch', 'Snack', 'Dinner']),
      ),
      myFoods: _seededMyFoods,
    );
    // Tap the first catalog row to enter the confirm step.
    await tester.tap(find.text('Chicken breast, grilled'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/food_picker_confirm.png'));
  });
}
