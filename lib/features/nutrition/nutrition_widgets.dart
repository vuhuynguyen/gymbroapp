import 'package:flutter/material.dart';

import '../../data/models/nutrition_models.dart';
import '../../domain/enums.dart';
import '../../shared/widgets/widgets.dart';

// ── Formatting helpers ──────────────────────────────────────────────────────

String fmtQty(num q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

/// "1 bowl ×2 · 320 kcal · 24P · 40C · 6F" — serving + scaled macros, omitting any null component.
String macroLine(NutritionItem i) {
  final parts = <String>[];
  final serving = i.servingLabel;
  if (serving != null && serving.isNotEmpty) {
    parts.add(i.quantity == 1 ? serving : '$serving ×${fmtQty(i.quantity)}');
  }
  num scale(num? v) => (v ?? 0) * i.quantity;
  if (i.energyKcal != null) parts.add('${scale(i.energyKcal).round()} kcal');
  final macros = <String>[
    if (i.proteinG != null) '${scale(i.proteinG).round()}P',
    if (i.carbsG != null) '${scale(i.carbsG).round()}C',
    if (i.fatG != null) '${scale(i.fatG).round()}F',
  ];
  if (macros.isNotEmpty) parts.add(macros.join(' '));
  return parts.join(' · ');
}

/// "7h 30m" / "8h" — the daily-check-in sleep readout.
String fmtSleep(num hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ── Item control (the sacred 44px tap target) ───────────────────────────────

/// Leading status control on an item row. One tap completes/uncompletes a planned item; the parent
/// opens the action sheet for skip/swap. 44px hit area, 28px inner glyph.
class NutriControl extends StatelessWidget {
  const NutriControl({required this.status, this.onTap, super.key});
  final NutritionItemStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    Widget inner;
    switch (status) {
      case NutritionItemStatus.completed:
        inner = _circle(gb.emerald,
            child: const Icon(Icons.check, size: 17, color: Colors.white),
            glow: gb.emerald);
      case NutritionItemStatus.substituted:
        inner = Stack(
          clipBehavior: Clip.none,
          children: [
            _circle(gb.emerald,
                child: const Icon(Icons.check, size: 17, color: Colors.white),
                glow: gb.emerald),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: gb.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: gb.card, width: 1.5)),
                child: Icon(Icons.swap_horiz, size: 10, color: gb.primary600),
              ),
            ),
          ],
        );
      case NutritionItemStatus.skipped:
        inner = _circle(gb.grey25,
            child: Icon(Icons.remove, size: 16, color: gb.grey500));
      case NutritionItemStatus.missed:
        inner = _circle(gb.danger0,
            child: Icon(Icons.flag_outlined, size: 15, color: gb.danger));
      case NutritionItemStatus.planned:
        inner = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: gb.card,
            shape: BoxShape.circle,
            border: Border.all(color: gb.borderField, width: AppSizes.border),
          ),
        );
    }

    final label = switch (status) {
      NutritionItemStatus.completed => 'Completed, tap to undo',
      NutritionItemStatus.substituted => 'Swapped',
      NutritionItemStatus.skipped => 'Skipped',
      NutritionItemStatus.missed => 'Missed',
      NutritionItemStatus.planned => 'Mark eaten',
    };

    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Center(child: inner)),
      ),
    );
  }

  Widget _circle(Color color, {required Widget child, Color? glow}) =>
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow == null
              ? null
              : [
                  BoxShadow(
                      color: glow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: -2)
                ],
        ),
        child: child,
      );
}

/// Status pill on an item row — shown only for swapped / skipped / missed (planned & completed read
/// from the control alone, keeping the row calm).
class NutriStatusChip extends StatelessWidget {
  const NutriStatusChip(this.status, {super.key});
  final NutritionItemStatus status;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg, icon, text) = switch (status) {
      NutritionItemStatus.substituted => (
          gb.primary0,
          gb.primary700,
          Icons.swap_horiz,
          'Swapped'
        ),
      NutritionItemStatus.skipped => (
          gb.grey25,
          gb.grey600,
          Icons.remove,
          'Skipped'
        ),
      NutritionItemStatus.missed => (
          gb.danger0,
          gb.danger,
          Icons.flag_outlined,
          'Missed'
        ),
      _ => (Colors.transparent, Colors.transparent, null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Kind pill on an item row — shown for supplement / beverage so they read distinctly from food
/// (food is the default and stays untagged to keep the row calm).
class NutriKindTag extends StatelessWidget {
  const NutriKindTag(this.kind, {super.key});
  final FoodKind kind;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg, icon) = switch (kind) {
      FoodKind.supplement => (
          gb.primary0,
          gb.primary600,
          Icons.medication_outlined
        ),
      FoodKind.beverage => (
          gb.secondary0,
          gb.secondary300,
          Icons.local_drink_outlined
        ),
      FoodKind.food => (Colors.transparent, Colors.transparent, null),
    };
    if (icon == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(kind.label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Small amber "Unverified" tag — flags a client-created / edited food in the coach's view.
class NutriUnverifiedTag extends StatelessWidget {
  const NutriUnverifiedTag({this.label = 'Unverified', super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: gb.amberSoft, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: gb.amberInk)),
    );
  }
}

// ── Item row ────────────────────────────────────────────────────────────────

/// One food item — the control, food name + status, a macro line, and a kebab. Read-only on closed
/// days / coach views (control disabled, no kebab). [showUnverified] tags client custom/edited foods.
class NutriItemRow extends StatelessWidget {
  const NutriItemRow({
    required this.item,
    this.onControlTap,
    this.onMore,
    this.readOnly = false,
    this.showUnverified = false,
    super.key,
  });

  final NutritionItem item;
  final VoidCallback? onControlTap;
  final VoidCallback? onMore;
  final bool readOnly;
  final bool showUnverified;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final skipped = item.status == NutritionItemStatus.skipped;
    final flagged = showUnverified && (item.isCustom || item.isEdited);

    return Opacity(
      opacity: skipped ? 0.78 : 1,
      child: GbCard(
        padding: const EdgeInsets.fromLTRB(2, 6, AppSpacing.sm, 6),
        onTap: readOnly ? null : onMore,
        child: Row(
          children: [
            NutriControl(
                status: item.status, onTap: readOnly ? null : onControlTap),
            const SizedBox(width: AppSpacing.xs - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.foodName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: skipped ? gb.grey500 : gb.ink,
                            decoration:
                                skipped ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      NutriStatusChip(item.status),
                      if (item.kind != FoodKind.food) ...[
                        const SizedBox(width: 5),
                        NutriKindTag(item.kind),
                      ],
                      if (item.isAdhoc) ...[
                        const SizedBox(width: 5),
                        const SourceTag(SessionSource.adhoc, small: true),
                      ],
                      if (flagged) ...[
                        const SizedBox(width: 5),
                        NutriUnverifiedTag(
                            label: item.isEdited ? 'Edited' : 'Custom'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(macroLine(item),
                      style: AppText.meta.copyWith(color: gb.grey500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (item.status == NutritionItemStatus.substituted &&
                      item.swappedFromName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text('was ${item.swappedFromName}',
                          style: TextStyle(fontSize: 11, color: gb.grey400)),
                    ),
                ],
              ),
            ),
            if (!readOnly && onMore != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.more_vert, size: AppSizes.iconXl, color: gb.grey400),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Meal header ──────────────────────────────────────────────────────────────

/// A meal section heading — name + scheduled time, with a tiny completion ring over its planned items.
class NutriMealHeader extends StatelessWidget {
  const NutriMealHeader({required this.meal, super.key});
  final NutritionMeal meal;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final planned = meal.plannedItems.length;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, AppSpacing.xs - 2),
      child: Row(
        children: [
          Text(meal.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          if (meal.scheduledTime != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.schedule, size: 12, color: gb.grey400),
            const SizedBox(width: 3),
            Text(_hhmm(meal.scheduledTime!),
                style: TextStyle(fontSize: 12, color: gb.grey500)),
          ],
          const Spacer(),
          if (planned > 0) ...[
            GbRing(
              value: planned > 0 ? meal.plannedDone / planned : 0,
              size: 24,
              stroke: 3.5,
              gradient: const [AppPalette.restRingLight, AppPalette.emerald],
            ),
            const SizedBox(width: 6),
            Text('${meal.plannedDone}/$planned',
                style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: gb.grey600)
                    .tabular),
          ],
        ],
      ),
    );
  }

  static String _hhmm(String t) {
    final parts = t.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : t;
  }
}

// ── Adherence ring card (the Today hero stat) ────────────────────────────────

class NutriAdherenceCard extends StatelessWidget {
  const NutriAdherenceCard({required this.log, super.key});
  final DailyNutritionLog log;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final total = log.plannedCount;
    final done = log.completedCount;
    final remaining = (total - done).clamp(0, total);
    final headline = log.isClosed
        ? (log.adherencePct >= 80 ? 'Solid day — plan followed' : 'Day closed')
        : (total == 0
            ? 'Nothing planned today'
            : (remaining == 0
                ? 'Plan complete — nice work'
                : '$remaining ${remaining == 1 ? 'item' : 'items'} to go'));

    return GbCard(
      padding: const EdgeInsets.all(AppSpacing.heroPad),
      child: Row(
        children: [
          GbRing(
            value: log.adherenceFraction,
            size: 74,
            stroke: 8,
            gradient: const [AppPalette.primary200, AppPalette.primary700],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${log.adherencePct}%',
                    style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1)
                        .tabular),
                Text('$done of $total',
                    style: TextStyle(
                            fontSize: 10,
                            color: gb.grey400,
                            fontWeight: FontWeight.w700)
                        .tabular),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.heroPad),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Today’s plan'),
                const SizedBox(height: 3),
                Text(headline,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: gb.ink,
                        letterSpacing: -0.15)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _stat(context, '${log.loggedKcal.round()}', 'kcal'),
                    const SizedBox(width: 22),
                    _stat(context, '${log.loggedProtein.round()}', 'protein g'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: gb.ink)
                .tabular),
        const SizedBox(height: 1),
        Eyebrow(label),
      ],
    );
  }
}

// ── Day summary card (history / coach list) ──────────────────────────────────

class NutriDayCard extends StatelessWidget {
  const NutriDayCard({required this.day, this.onTap, super.key});
  final NutritionDaySummary day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          GbRing(
            value: day.adherenceFraction,
            size: 40,
            stroke: 5,
            gradient: const [AppPalette.primary200, AppPalette.primary700],
            child: Text('${day.adherencePct}%',
                style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: gb.grey900)
                    .tabular),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(_dayLabel(day.date, day.localDate),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    SourceTag(day.source, small: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    '${day.completedCount}/${day.plannedCount} completed'
                    '${day.skippedCount > 0 ? ' · ${day.skippedCount} skipped' : ''}',
                    style: AppText.meta.copyWith(color: gb.grey500)),
              ],
            ),
          ),
          if (day.missedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GbStatusBadge(
                  label: '${day.missedCount} missed',
                  background: gb.danger0,
                  foreground: gb.danger),
            ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: AppSizes.iconLg, color: gb.grey400),
        ],
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _dayLabel(DateTime? d, String fallback) {
    if (d == null) return fallback;
    final today = DateTime.now();
    final dayOnly = DateTime(d.year, d.month, d.day);
    final diff =
        DateTime(today.year, today.month, today.day).difference(dayOnly).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

/// Skeleton for the Today nutrition section — a ring-card placeholder over a few item rows.
class NutriSkeleton extends StatelessWidget {
  const NutriSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GbSkeleton(height: 104, radius: AppRadius.md),
        const SizedBox(height: AppSpacing.gap),
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xs),
            child: GbSkeleton(height: 58, radius: AppRadius.md),
          ),
      ],
    );
  }
}
