import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/nutrition_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';
import 'food_picker_sheet.dart';
import 'nutrition_providers.dart';
import 'nutrition_widgets.dart';

/// The per-item action sheet (design §D) — Complete / Skip / Swap for a planned item, Remove for an
/// ad-hoc one. All actions are optimistic via [TodayNutritionController]; errors surface a snackbar.
void showNutriItemSheet(
    BuildContext context, WidgetRef ref, NutritionItem item) {
  final controller = ref.read(todayNutritionProvider.notifier);

  Future<void> run(Future<void> Function() action) async {
    Navigator.of(context).pop();
    try {
      await action();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<void> swap() async {
    Navigator.of(context).pop();
    final pick = await showFoodPicker(context,
        swap: true, swapTargetName: item.foodName);
    if (pick == null) return;
    try {
      await controller.swap(item, pick.food, quantity: pick.quantity);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  showGbSheet<void>(
    context,
    builder: (_) {
      final gb = context.gb;
      final s = item.status;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GbSheetHeader(title: item.foodName, subtitle: macroLine(item)),
            const SizedBox(height: AppSpacing.sm),
            if (item.isAdhoc)
              GbSheetActionTile(
                icon: Icons.delete_outline,
                iconColor: gb.danger,
                label: 'Remove',
                sub: 'Take this off-plan item off today',
                onTap: () => run(() => controller.removeItem(item)),
              )
            else ...[
              if (s != NutritionItemStatus.completed &&
                  s != NutritionItemStatus.substituted)
                GbSheetActionTile(
                  icon: Icons.check_circle_outline,
                  iconColor: gb.emerald,
                  label: 'Complete',
                  sub: 'Ate it as planned',
                  onTap: () => run(() => controller.setStatus(
                      item, NutritionItemStatus.completed)),
                ),
              if (s != NutritionItemStatus.skipped)
                GbSheetActionTile(
                  icon: Icons.remove_circle_outline,
                  label: 'Skip',
                  sub: 'Deliberately passing on this one',
                  onTap: () => run(() =>
                      controller.setStatus(item, NutritionItemStatus.skipped)),
                ),
              GbSheetActionTile(
                icon: Icons.swap_horiz,
                iconColor: gb.primary600,
                label: 'Swap',
                sub: 'Log a different food instead',
                onTap: swap,
              ),
              if (s != NutritionItemStatus.planned)
                GbSheetActionTile(
                  icon: Icons.undo,
                  label: 'Reset to planned',
                  sub: 'Clear today’s status',
                  onTap: () => run(() =>
                      controller.setStatus(item, NutritionItemStatus.planned)),
                ),
            ],
          ],
        ),
      );
    },
  );
}

// ── Daily check-in (weight + sleep) ─────────────────────────────────────────

/// The body check-in card on Log's Today surface — two cells (weight / sleep). [readOnly] (the coach
/// view) shows the logged values with no logging affordance.
class DailyCheckinCard extends ConsumerWidget {
  const DailyCheckinCard({this.readOnly = false, this.value, super.key});

  /// Override the bound provider value (the coach passes a client's check-in directly).
  final DailyCheckin? value;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gb = context.gb;
    final checkin = value ??
        (readOnly
            ? DailyCheckin.empty
            : ref.watch(checkinProvider).valueOrNull ?? DailyCheckin.empty);

    return GbCard(
      padding:
          const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _CheckinCell(
                icon: Icons.monitor_weight_outlined,
                tint: gb.primary0,
                iconColor: gb.primary600,
                label: 'WEIGHT',
                value: checkin.weightKg == null
                    ? null
                    : '${fmtQty(checkin.weightKg!)} kg',
                onTap: readOnly
                    ? null
                    : () => _openSheet(context, ref,
                        weight: true, current: checkin.weightKg),
              ),
            ),
            VerticalDivider(width: 1, color: gb.borderCard),
            Expanded(
              child: _CheckinCell(
                icon: Icons.bedtime_outlined,
                tint: gb.secondary0,
                iconColor: gb.secondary300,
                label: 'SLEEP',
                value: checkin.sleepHours == null
                    ? null
                    : fmtSleep(checkin.sleepHours!),
                onTap: readOnly
                    ? null
                    : () => _openSheet(context, ref,
                        weight: false, current: checkin.sleepHours),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref,
      {required bool weight, num? current}) {
    showGbSheet<void>(
      context,
      builder: (_) => _CheckinSheet(weight: weight, current: current),
    );
  }
}

class _CheckinCell extends StatelessWidget {
  const _CheckinCell({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        child: Row(
          children: [
            GbIconTile(
                size: 38,
                background: tint,
                child: Icon(icon, size: AppSizes.iconLg, color: iconColor)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Eyebrow(label),
                  const SizedBox(height: 2),
                  if (value != null)
                    Row(
                      children: [
                        Flexible(
                          child: Text(value!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: gb.ink)
                                  .tabular),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle, size: 13, color: gb.emerald),
                        ],
                      ],
                    )
                  else if (onTap != null)
                    Text('+ Log',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: gb.primary600))
                  else
                    Text('—',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: gb.grey400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinSheet extends ConsumerStatefulWidget {
  const _CheckinSheet({required this.weight, this.current});
  final bool weight;
  final num? current;

  @override
  ConsumerState<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends ConsumerState<_CheckinSheet> {
  late num _value = widget.current ?? (widget.weight ? 70 : 8);
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final c = ref.read(checkinProvider.notifier);
      await (widget.weight ? c.logWeight(_value) : c.logSleep(_value));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GbSheetHeader(
            title: widget.weight ? 'Log weight' : 'Log sleep',
            subtitle: widget.weight
                ? 'Today’s body weight (self-reported).'
                : 'Hours slept last night.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: GbStepper(
              value: _value,
              step: widget.weight ? 0.1 : 0.25,
              unit: widget.weight ? 'kg' : 'h',
              semanticLabel: widget.weight ? 'Weight' : 'Sleep hours',
              onChanged: (v) => setState(() =>
                  _value = widget.weight ? (v < 30 ? 30 : v) : (v < 0 ? 0 : v)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GbButton(
              label: 'Save',
              full: true,
              busy: _busy,
              onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
