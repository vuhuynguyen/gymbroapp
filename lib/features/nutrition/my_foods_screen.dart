import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/nutrition_models.dart';
import '../../shared/widgets/widgets.dart';
import 'custom_food_form.dart';
import 'food_kind_style.dart';
import 'my_foods_store.dart';

/// The trainee's device-local "My foods" library — customs they invented and edited catalog
/// variants. View, add a reusable food (no logging needed), edit, or delete. Anything here surfaces
/// under the "My foods" filter in the food picker.
class MyFoodsScreen extends ConsumerWidget {
  const MyFoodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final foodsAsync = ref.watch(myFoodsProvider);

    return Scaffold(
      backgroundColor: gb.canvas,
      body: Column(
        children: [
          _Header(onAdd: () => _openEditor(context, ref)),
          Expanded(
            child: foodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(
                  message: e.toString(),
                  onRetry: () async => ref.invalidate(myFoodsProvider)),
              data: (foods) =>
                  foods.isEmpty ? _empty(context, ref) : _list(context, ref, foods),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: gb.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: gb.borderField, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: gb.grey25, borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.star_border, size: 24, color: gb.grey400),
              ),
              const SizedBox(height: 12),
              Text('No saved foods yet',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: gb.ink)),
              const SizedBox(height: 5),
              Text(
                "Save foods you eat often — your own recipes or your brand's macros — "
                'and reuse them in one tap when you log.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.55, color: gb.grey500),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: GbButton(
                  label: 'Add your first food',
                  icon: Icons.add,
                  onPressed: () => _openEditor(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<Food> foods) {
    final gb = context.gb;
    final customs = foods.where((f) => f.isCustom).toList();
    final variants = foods.where((f) => !f.isCustom).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        // Info bar
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.star, size: 15, color: gb.primary500),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: gb.grey500),
                    children: [
                      const TextSpan(text: 'These appear under '),
                      TextSpan(
                          text: 'My foods',
                          style: TextStyle(
                              color: gb.grey700, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' in the food picker.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (customs.isNotEmpty) ...[
          _sectionHeader(context, 'Custom foods', customs.length, top: 2),
          for (final f in customs) _card(context, ref, f),
        ],
        if (variants.isNotEmpty) ...[
          _sectionHeader(context, 'Edited variants', variants.length, top: 12),
          for (final f in variants) _card(context, ref, f),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count, {required double top}) {
    final gb = context.gb;
    return Padding(
      padding: EdgeInsets.fromLTRB(2, top, 2, 9),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: gb.ink)),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: gb.grey400)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Food f) =>
      _MyFoodCard(
        food: f,
        onEdit: () => _openEditor(context, ref, food: f),
        onDelete: () => _confirmDelete(context, ref, f),
      );

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Food? food}) async {
    final gb = context.gb;
    final editing = food != null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: gb.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (ctx, scroll) => Padding(
          padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 4,
              // Keyboard inset when open; otherwise clear the home indicator so the Save CTA
              // isn't jammed against the bottom edge.
              bottom: MediaQuery.of(ctx).viewInsets.bottom > 0
                  ? MediaQuery.of(ctx).viewInsets.bottom
                  : MediaQuery.of(ctx).padding.bottom + 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(editing ? 'Edit food' : 'New food',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: gb.grey900)),
                        const SizedBox(height: 1),
                        Text('Saved to My foods — reuse it any time you log.',
                            style: TextStyle(fontSize: 12.5, color: gb.grey500)),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                      icon: Icons.close, onTap: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: CustomFoodForm(
                  initial: food,
                  submitLabel: editing ? 'Save changes' : 'Save food',
                  submitIcon: Icons.check,
                  note:
                      "Saved to My foods on this device — it won't change your gym's catalog.",
                  onContinue: (saved) {
                    ref.read(myFoodsProvider.notifier).save(saved.copyWith(mine: true));
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Food f) async {
    final gb = context.gb;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: gb.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete this food?',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: gb.grey900)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, color: gb.grey500, height: 1.45),
                  children: [
                    TextSpan(
                        text: f.name,
                        style: TextStyle(
                            color: gb.grey700, fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text: ' will be removed from My foods. Items you already '
                            'logged with it stay as they are.'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GbButton(
                      label: 'Cancel',
                      variant: GbButtonVariant.outlined,
                      severity: GbButtonSeverity.secondary,
                      full: true,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GbButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      severity: GbButtonSeverity.danger,
                      full: true,
                      onPressed: () {
                        ref.read(myFoodsProvider.notifier).delete(f.id);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      decoration: BoxDecoration(
        color: gb.card,
        border: Border(bottom: BorderSide(color: gb.borderCard)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.chevron_left,
                size: 40,
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('My foods',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: gb.grey900)),
                    Text('Saved foods you can reuse when logging',
                        style: TextStyle(fontSize: 12, color: gb.grey500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GbButton(label: 'Add', icon: Icons.add, size: GbButtonSize.sm, onPressed: onAdd),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyFoodCard extends StatelessWidget {
  const _MyFoodCard({required this.food, required this.onEdit, required this.onDelete});
  final Food food;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final f = food;
    String n(num? v) => v == null ? '0' : (v == v.roundToDouble() ? v.round().toString() : '$v');
    final meta = [
      if (f.brand != null) f.brand!,
      if (f.servingLabel != null) f.servingLabel!,
      '${n(f.energyKcal)} kcal',
      '${n(f.proteinG)}P',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: gb.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: gb.borderCard),
        boxShadow: gb.cardShadow,
      ),
      child: Row(
        children: [
          FoodTile(kind: f.kind, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: gb.grey900)),
                    ),
                    if (f.isCustom || f.isEdited) ...[
                      const SizedBox(width: 7),
                      FoodMineTag(label: f.isCustom ? 'Custom' : 'Edited'),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    FoodKindChip(kind: f.kind),
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
          _SquareIconButton(icon: Icons.edit_outlined, onTap: onEdit),
          const SizedBox(width: 2),
          _SquareIconButton(
              icon: Icons.delete_outline, color: gb.danger, onTap: onDelete),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap, this.size = 36});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Material(
      color: gb.grey0,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size < 38 ? 17 : 20, color: gb.grey700),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Material(
      color: gb.grey0,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 16, color: color ?? gb.grey600),
        ),
      ),
    );
  }
}
