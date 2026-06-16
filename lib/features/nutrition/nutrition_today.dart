import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/nutrition_models.dart';
import '../../shared/widgets/widgets.dart';
import 'food_picker_sheet.dart';
import 'nutrition_providers.dart';
import 'nutrition_sheets.dart';
import 'nutrition_widgets.dart';

/// Quick off-plan food logging — shared by Today's "Log off-plan food" row and the bottom-nav "+"
/// chooser. Reads today's log for the meal slots, opens the food picker, and adds the pick off-plan.
/// On a closed day it just tells the user logging is locked; a dismissed picker is a silent no-op.
Future<void> logQuickFood(BuildContext context, WidgetRef ref) async {
  final log = ref.read(todayNutritionProvider).valueOrNull;
  if (log != null && log.isClosed) {
    showInfoSnack(context, 'Today is closed — logging is locked.');
    return;
  }
  final pick =
      await showFoodPicker(context, swap: false, meals: nutritionMealSlots(log));
  if (pick == null || !context.mounted) return;
  try {
    await ref.read(todayNutritionProvider.notifier).addOffPlan(pick.food,
        quantity: pick.quantity, mealName: pick.mealName);
    if (context.mounted) showInfoSnack(context, 'Logged ${pick.food.name}.');
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}

/// Meal slots for the food picker — the day's own meals first (a plan may use custom names), then the
/// standard slots so a trainee can always pick Breakfast/Lunch/Dinner/Snack with no plan assigned.
const _standardMeals = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
List<String> nutritionMealSlots(DailyNutritionLog? log) {
  final seen = <String>{};
  return [
    if (log != null)
      for (final m in log.meals)
        if (seen.add(m.name)) m.name,
    for (final m in _standardMeals)
      if (seen.add(m)) m,
  ];
}

/// A muted section header used inside Log's Today pane (e.g. "Workout", "Nutrition"), with an optional
/// trailing action link (the Nutrition section's "History →").
class TodaySectionHeader extends StatelessWidget {
  const TodaySectionHeader(
      {required this.icon,
      required this.title,
      this.actionLabel,
      this.onAction,
      super.key});
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMd, color: gb.grey400),
          const SizedBox(width: 6),
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(actionLabel!,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: gb.primary600)),
                  Icon(Icons.chevron_right,
                      size: AppSizes.iconMd, color: gb.primary600),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The nutrition portion of Log's Today surface: the "Nutrition" header (+ History link), the
/// adherence ring card, the daily check-in, the meal checklist, and the off-plan logging CTA. Covers
/// loading / no-plan / closed-day / populated states. The single-tap complete loop is optimistic.
class NutritionTodaySection extends ConsumerWidget {
  const NutritionTodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final async = ref.watch(todayNutritionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TodaySectionHeader(
          icon: Icons.restaurant_menu,
          title: 'Nutrition',
          actionLabel: (async.valueOrNull?.hasPlan ?? false) ? 'History' : null,
          onAction: () => context.push('/nutrition-history'),
        ),
        const SizedBox(height: AppSpacing.xs),
        async.when(
          loading: () => const NutriSkeleton(),
          error: (e, _) => ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.read(todayNutritionProvider.notifier).reload(),
          ),
          data: (log) => _content(context, ref, log, gb),
        ),
      ],
    );
  }

  Widget _content(
      BuildContext context, WidgetRef ref, DailyNutritionLog log, GbColors gb) {
    final controller = ref.read(todayNutritionProvider.notifier);
    final hasMeals = log.meals.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (log.isClosed) ...[
          _ClosedBanner(),
          const SizedBox(height: AppSpacing.xs),
        ],
        // One nutrition summary: adherence ring + items + all-source calories (logged / target) and
        // protein. Shown always — with no plan it reads the logged-item count + logged calories.
        NutriAdherenceCard(log: log),
        const SizedBox(height: AppSpacing.gap),
        const DailyCheckinCard(),
        const SizedBox(height: AppSpacing.gap),
        // Off-plan logging leads the food section (an "add" affordance belongs at the top, not buried
        // under the meal list) — always available on an open day, even with no assigned plan.
        if (!log.isClosed) ...[
          GbTappableRow(
            dashed: true,
            leading: GbIconTile(
                background: gb.grey25,
                child: Icon(Icons.add, size: 21, color: gb.grey600)),
            title: 'Log off-plan food',
            subtitle: 'Anything you ate outside the plan',
            onTap: () => logQuickFood(context, ref),
          ),
          const SizedBox(height: AppSpacing.gap),
        ],
        if (log.hasPlan || hasMeals)
          for (final meal in log.meals) ...[
            NutriMealHeader(meal: meal),
            for (final item in meal.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: NutriItemRow(
                  item: item,
                  readOnly: log.isClosed,
                  onControlTap: () =>
                      _run(context, () => controller.toggleComplete(item)),
                  onMore: () => showNutriItemSheet(context, ref, item),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
          ]
        else
          _NoPlanBlock(),
      ],
    );
  }

  Future<void> _run(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }
}

/// Calm "your coach assigns this" block shown when the trainee has no active nutrition plan.
class _NoPlanBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      dashed: true,
      padding: const EdgeInsets.all(AppSpacing.heroPad),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu,
              size: AppSizes.iconXxl + 4, color: gb.grey400),
          const SizedBox(height: AppSpacing.xs),
          Text('No nutrition plan yet',
              style: AppText.rowTitle.copyWith(color: gb.grey700)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
              'Your coach assigns your meal plan — it’ll appear here, ready to log.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: gb.grey400)),
        ],
      ),
    );
  }
}

/// Closed-day lock banner — logging is locked; unlogged plan items read as missed.
class _ClosedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(color: gb.grey25, borderRadius: AppRadius.brSm),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: AppSizes.iconMd, color: gb.grey500),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
                'Day closed — logging is locked. Unlogged items show as missed.',
                style: TextStyle(fontSize: 12, height: 1.4, color: gb.grey600)),
          ),
        ],
      ),
    );
  }
}
