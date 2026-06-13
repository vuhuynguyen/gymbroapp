import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/nutrition_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import 'custom_food_form.dart';
import 'food_kind_style.dart';
import 'my_foods_store.dart';
import 'nutrition_providers.dart';

/// The result of a food-picker session: the chosen food, serving quantity, and (add mode) the meal
/// it should be logged under.
typedef FoodPickResult = ({Food food, num quantity, String? mealName});

/// Open the food picker to log an off-plan item ([swap] = false) or substitute a planned one
/// ([swap] = true). [meals] are the day's meal names for the "Log under" chips; [swapTargetName] is
/// the planned item being replaced (shown in the swap banner).
Future<FoodPickResult?> showFoodPicker(
  BuildContext context, {
  required bool swap,
  List<String> meals = const [],
  String? swapTargetName,
}) {
  return showModalBottomSheet<FoodPickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.gb.card,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _FoodPickerSheet(
        swap: swap, meals: meals, swapTargetName: swapTargetName),
  );
}

/// Test seam — renders the picker sheet directly so its styling can be verified with goldens.
@visibleForTesting
Widget buildFoodPickerForTest(
        {required bool swap,
        List<String> meals = const [],
        String? swapTargetName}) =>
    _FoodPickerSheet(swap: swap, meals: meals, swapTargetName: swapTargetName);

class _FoodPickerSheet extends ConsumerStatefulWidget {
  const _FoodPickerSheet({
    required this.swap,
    required this.meals,
    this.swapTargetName,
  });
  final bool swap;
  final List<String> meals;
  final String? swapTargetName;

  @override
  ConsumerState<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<_FoodPickerSheet> {
  String _query = '';
  FoodKind? _kind; // null = "All" (unless _mine)
  bool _mine = false; // the "My foods" filter
  Food? _selected; // non-null ⇒ confirm step
  bool _custom = false; // the custom-food form
  num _quantity = 1;
  String? _meal;
  bool _saveMine = false;

  /// In add mode the user must pick a meal (no auto-selection); swaps don't use a meal.
  bool get _needsMeal => !widget.swap && widget.meals.isNotEmpty;
  String get _chosenMeal =>
      _meal ?? (widget.meals.isNotEmpty ? widget.meals.last : 'Snack');

  void _choose(Food f) {
    setState(() {
      _selected = f;
      _quantity = 1;
      _saveMine = f.isCustom && !f.mine; // customs default to being kept
    });
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Padding(
        padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 4,
            // Keyboard inset when open; otherwise clear the home indicator + a little breathing room
            // so the bottom CTA never crowds the nav bar.
            bottom: MediaQuery.of(ctx).viewInsets.bottom > 0
                ? MediaQuery.of(ctx).viewInsets.bottom
                : MediaQuery.of(ctx).padding.bottom + 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(gb),
            const SizedBox(height: 10),
            Expanded(
              child: _selected != null
                  ? _confirm(gb, scroll, _selected!)
                  : _custom
                      ? CustomFoodForm(
                          initialName: _query.trim(),
                          submitLabel: 'Continue',
                          onContinue: _choose,
                        )
                      : _search(gb, scroll),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(GbColors gb) {
    final showBack = _selected != null || _custom;
    final title = _selected != null
        ? 'Confirm'
        : _custom
            ? 'Custom food'
            : widget.swap
                ? 'Swap food'
                : 'Log food';
    String? subtitle;
    if (_selected == null && !_custom) {
      subtitle = widget.swap
          ? 'Replaces ${widget.swapTargetName ?? 'the planned item'}'
          : 'Search the catalog to log an off-plan item.';
    } else if (_custom && _selected == null) {
      subtitle = 'Not in the catalog? Describe it yourself.';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack) ...[
          _circleBtn(Icons.chevron_left, () {
            setState(() {
              if (_selected != null) {
                _selected = null;
              } else {
                _custom = false;
              }
            });
          }),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: gb.grey900)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: gb.grey500)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _circleBtn(Icons.close, () => Navigator.of(context).pop()),
      ],
    );
  }

  // ── Search + results ──────────────────────────────────────────────────────
  Widget _search(GbColors gb, ScrollController scroll) {
    final myFoods = ref.watch(myFoodsProvider).valueOrNull ?? const <Food>[];
    final q = _query.trim().toLowerCase();
    bool matches(Food f) =>
        q.isEmpty || ('${f.name} ${f.brand ?? ''}').toLowerCase().contains(q);
    final mineFiltered = myFoods
        .where((f) => matches(f) && (_mine || _kind == null || f.kind == _kind))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchField(gb),
        const SizedBox(height: 12),
        _kindChips(gb),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: GbButton(
            label: 'Manage my foods',
            iconRight: Icons.chevron_right,
            variant: GbButtonVariant.text,
            size: GbButtonSize.sm,
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/my-foods');
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _mine
              ? _resultList(gb, scroll, mineFiltered, includeCustomEntry: true)
              : ref
                  .watch(foodSearchProvider((search: _query, kind: _kind)))
                  .when(
                    loading: () => const GbSkeletonList(
                        count: 6, itemHeight: 64, padding: EdgeInsets.zero),
                    error: (e, _) => ErrorRetry(
                      message: e.toString(),
                      onRetry: () async => ref.invalidate(
                          foodSearchProvider((search: _query, kind: _kind))),
                    ),
                    data: (list) {
                      // Saved foods surface first (deduped against the catalog by id).
                      final mineIds = mineFiltered.map((f) => f.id).toSet();
                      final merged = [
                        ...mineFiltered,
                        ...list.items.where((f) => !mineIds.contains(f.id)),
                      ];
                      return _resultList(gb, scroll, merged,
                          includeCustomEntry: true);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _searchField(GbColors gb) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        // Design: a single filled search box, no outline.
        color: gb.grey0,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: gb.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: gb.grey400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              // No autofocus — let the user see the list before the keyboard covers it.
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 15, color: gb.grey900),
              // All states none — otherwise the theme's focusedBorder leaks a blue box on focus.
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search foods…',
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _query = ''),
              child: Icon(Icons.close, size: 15, color: gb.grey400),
            ),
        ],
      ),
    );
  }

  Widget _kindChips(GbColors gb) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(gb, 'All',
              selected: !_mine && _kind == null,
              onTap: () => setState(() {
                    _mine = false;
                    _kind = null;
                  })),
          for (final k in FoodKind.values)
            _chip(gb, k.label,
                selected: !_mine && _kind == k,
                onTap: () => setState(() {
                      _mine = false;
                      _kind = k;
                    })),
          _chip(gb, 'My foods',
              icon: Icons.star,
              selected: _mine,
              onTap: () => setState(() => _mine = true)),
        ],
      ),
    );
  }

  Widget _chip(GbColors gb, String label,
      {required bool selected, required VoidCallback onTap, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? gb.ink : gb.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? Colors.transparent : gb.borderCard,
                width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14, color: selected ? Colors.white : gb.grey600),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : gb.grey600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultList(GbColors gb, ScrollController scroll, List<Food> items,
      {required bool includeCustomEntry}) {
    if (items.isEmpty) {
      return _emptyResults(gb, scroll);
    }
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // First — the catalog can be long, so keep the custom-food shortcut reachable up top.
        if (includeCustomEntry) ...[
          _customEntryRow(gb),
          const SizedBox(height: 10),
        ],
        for (final f in items) _FoodResultRow(food: f, onTap: () => _choose(f)),
      ],
    );
  }

  Widget _customEntryRow(GbColors gb) {
    return GestureDetector(
      onTap: () => setState(() => _custom = true),
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: gb.borderField, width: 1.5, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: gb.grey25, borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.add, size: 18, color: gb.grey600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Log a custom food',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: gb.grey900)),
                  const SizedBox(height: 2),
                  Text('Not in the catalog — enter it yourself',
                      style: TextStyle(fontSize: 12, color: gb.grey500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: gb.grey400),
          ],
        ),
      ),
    );
  }

  Widget _emptyResults(GbColors gb, ScrollController scroll) {
    final q = _query.trim();
    return ListView(
      controller: scroll,
      children: [
        const SizedBox(height: 36),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: gb.grey25, borderRadius: BorderRadius.circular(16)),
            child: Icon(_mine ? Icons.star_border : Icons.search,
                size: 24, color: gb.grey400),
          ),
        ),
        const SizedBox(height: 12),
        Text(
            _mine
                ? 'No saved foods yet'
                : q.isEmpty
                    ? 'Search the food catalog'
                    : 'No foods match “$q”',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: gb.ink)),
        const SizedBox(height: 5),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
                _mine
                    ? 'Save foods you eat often and reuse them in one tap when you log.'
                    : "You can still log it — describe it yourself and we'll track it like any other item.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12.5, height: 1.55, color: gb.grey500)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: GbButton(
              label: q.isEmpty ? 'Log a custom food' : 'Log “$q” as custom',
              icon: Icons.add,
              onPressed: () => setState(() => _custom = true),
            ),
          ),
        ),
      ],
    );
  }

  // ── Confirm ───────────────────────────────────────────────────────────────
  Widget _confirm(GbColors gb, ScrollController scroll, Food food) {
    num scale(num? v) => (v ?? 0) * _quantity;
    final canSave = (food.isCustom || food.isEdited) && !food.mine;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (widget.swap)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: gb.primary0, borderRadius: BorderRadius.circular(11)),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, size: 16, color: gb.primary600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Replaces ${widget.swapTargetName ?? 'the planned item'}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: gb.primary700)),
                ),
              ],
            ),
          ),
        // Food identity card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gb.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: gb.borderCard),
            boxShadow: gb.cardShadow,
          ),
          child: Row(
            children: [
              FoodTile(kind: food.kind, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(food.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: gb.grey900)),
                        FoodKindChip(kind: food.kind),
                        if (food.isCustom) const FoodMineTag(label: 'Custom'),
                        if (food.isEdited) const FoodMineTag(label: 'Edited'),
                        if (food.mine && !food.isCustom) const FoodMineTag(),
                      ],
                    ),
                    if (food.brand != null || food.servingLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            [
                              if (food.brand != null) food.brand!,
                              if (food.servingLabel != null) food.servingLabel!
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: gb.grey500)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Macro cards (scaled by quantity)
        Row(
          children: [
            _macroCard(gb, '${scale(food.energyKcal).round()}', 'kcal'),
            const SizedBox(width: 10),
            _macroCard(gb, '${scale(food.proteinG).round()}g', 'Protein'),
            const SizedBox(width: 10),
            _macroCard(gb, '${scale(food.carbsG).round()}g', 'Carbs'),
            const SizedBox(width: 10),
            _macroCard(gb, '${scale(food.fatG).round()}g', 'Fat'),
          ],
        ),
        const SizedBox(height: 14),
        // Servings
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Servings',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: gb.grey900)),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text('${food.servingLabel ?? '1 serving'} each',
                        style: TextStyle(fontSize: 12, color: gb.grey500)),
                  ),
                ],
              ),
            ),
            GbStepper(
              value: _quantity,
              step: 0.5,
              min: 0.5,
              semanticLabel: 'Servings',
              onChanged: (v) => setState(() => _quantity = v < 0.5 ? 0.5 : v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Meal assignment (add mode only)
        if (!widget.swap && widget.meals.isNotEmpty) ...[
          Text('Log under',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: gb.grey500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in widget.meals) _mealChip(gb, m),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Save to My foods
        if (canSave)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: gb.grey0,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gb.borderCard),
            ),
            child: Row(
              children: [
                Icon(Icons.star, size: 16, color: gb.grey500),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Save to My foods',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: gb.grey900)),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                            'Reuse it next time — find it under “My foods”',
                            style:
                                TextStyle(fontSize: 11.5, color: gb.grey500)),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _saveMine,
                  activeTrackColor: gb.primary500,
                  onChanged: (v) => setState(() => _saveMine = v),
                ),
              ],
            ),
          ),
        GbButton(
          label: widget.swap
              ? 'Swap food'
              : _needsMeal && _meal == null
                  ? 'Select a meal'
                  : 'Add to $_chosenMeal',
          icon: widget.swap ? Icons.swap_horiz : Icons.check,
          size: GbButtonSize.lg,
          full: true,
          // Add mode: stay disabled until the user chooses which meal to log under.
          onPressed: _needsMeal && _meal == null ? null : () => _commit(food),
        ),
      ],
    );
  }

  void _commit(Food food) {
    if (_saveMine && (food.isCustom || food.isEdited) && !food.mine) {
      ref.read(myFoodsProvider.notifier).save(food.copyWith(mine: true));
    }
    Navigator.of(context).pop((
      food: food,
      quantity: _quantity,
      mealName: widget.swap ? null : _chosenMeal,
    ));
  }

  Widget _macroCard(GbColors gb, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: gb.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gb.borderCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: gb.grey900)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: gb.grey400)),
          ],
        ),
      ),
    );
  }

  Widget _mealChip(GbColors gb, String m) {
    // Highlight only the user's explicit choice — no auto-selected default.
    final on = _meal == m;
    return GestureDetector(
      onTap: () => setState(() => _meal = m),
      child: Container(
        height: 36,
        // No `alignment` — inside a Wrap (bounded width) it would expand the pill to full width.
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? gb.primary500 : gb.card,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: on ? gb.primary500 : gb.borderCard, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : gb.grey600)),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    final gb = context.gb;
    return Material(
      color: gb.grey0,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: gb.grey700)),
      ),
    );
  }
}

/// A catalog / my-food search-result row (design `FoodResultRow`).
class _FoodResultRow extends StatelessWidget {
  const _FoodResultRow({required this.food, required this.onTap});
  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    String n(num? v) => v == null
        ? '0'
        : (v == v.roundToDouble() ? v.round().toString() : '$v');
    final meta =
        '${food.servingLabel ?? '1 serving'} · ${n(food.energyKcal)} kcal · ${n(food.proteinG)}P';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: gb.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: gb.borderCard),
        ),
        child: Row(
          children: [
            FoodTile(kind: food.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: gb.grey900)),
                      ),
                      if (food.brand != null) ...[
                        const SizedBox(width: 7),
                        Text(food.brand!,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: gb.grey400)),
                      ],
                      if (food.mine) ...[
                        const SizedBox(width: 7),
                        const FoodMineTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      FoodKindChip(kind: food.kind),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: gb.grey500)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: gb.grey400),
          ],
        ),
      ),
    );
  }
}
