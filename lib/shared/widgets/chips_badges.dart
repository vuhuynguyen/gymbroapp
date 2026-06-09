import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/enums.dart';

/// Plan vs Ad-hoc source pill (design `SourceTag`).
class SourceTag extends StatelessWidget {
  const SourceTag(this.source, {this.small = false, super.key});
  final SessionSource source;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final adhoc = source == SessionSource.adhoc;
    final fg = adhoc ? gb.adhocTag : gb.planTag;
    final bg = adhoc ? gb.warning0 : gb.primary0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 7, vertical: small ? 1 : 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(adhoc ? Icons.bolt : Icons.folder_outlined, size: small ? 10 : AppSizes.iconXs, color: fg),
          const SizedBox(width: 4),
          Text(adhoc ? 'Ad-hoc' : 'Plan',
              style: TextStyle(fontSize: small ? 10 : 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// Amber "PR" trophy chip (design `PRChip`).
class PrChip extends StatelessWidget {
  const PrChip({this.small = false, super.key});
  final bool small;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 2 : 3),
      decoration: BoxDecoration(color: gb.amberSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: small ? 11 : 13, color: gb.amber),
          const SizedBox(width: 4),
          Text('PR', style: TextStyle(fontSize: small ? 10 : 11, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: gb.amberInk)),
        ],
      ),
    );
  }
}

/// Amber streak chip (flame + count) shown in the Log header.
class GbStreakChip extends StatelessWidget {
  const GbStreakChip({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(color: gb.amberSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 15, color: gb.amber),
          const SizedBox(width: 5),
          Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: gb.amberInk).tabular),
        ],
      ),
    );
  }
}

/// Plan visibility badge — Full (eye/green) · Guided (sliders/blue) · Blind (lock/grey).
class VisBadge extends StatelessWidget {
  const VisBadge(this.mode, {super.key});
  final PlanVisibilityMode mode;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg, icon) = switch (mode) {
      PlanVisibilityMode.full => (gb.success0, gb.success, Icons.visibility_outlined),
      PlanVisibilityMode.guided => (gb.secondary0, gb.secondary300, Icons.tune),
      PlanVisibilityMode.blind => (gb.grey25, gb.grey600, Icons.lock_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(mode.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Small status pill (e.g. "On track" / "Behind" / "Paused") — colored soft-tint background.
class GbStatusBadge extends StatelessWidget {
  const GbStatusBadge({required this.label, required this.background, required this.foreground, this.stadium = true, super.key});
  final String label;
  final Color background;
  final Color foreground;
  final bool stadium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(stadium ? AppRadius.pill : 6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: foreground)),
    );
  }
}

/// Small outlined metadata pill (design `metaPill`) — e.g. muscle / equipment / "3 × 10 @ 22kg".
class GbMetaPill extends StatelessWidget {
  const GbMetaPill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: gb.grey0,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: gb.borderCard),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gb.grey700)),
    );
  }
}

/// Selectable pill chip (filter / day / pager / muscle chips) — solid fill when selected.
class GbChip extends StatelessWidget {
  const GbChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.selectedColor,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  /// Fill when selected — defaults to primary; Log filters pass ink (`grey900`).
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final sel = selectedColor ?? gb.primary500;
    final fg = selected ? Colors.white : gb.grey600;
    return Material(
      color: selected ? sel : gb.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? sel : gb.borderCard, width: AppSizes.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: AppSizes.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: AppSizes.iconSm, color: fg), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.13, color: fg)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg.withValues(alpha: 0.7)).tabular),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed-border pill (design "Add" affordance in the exercise pager).
class GbDashedPill extends StatelessWidget {
  const GbDashedPill({required this.child, required this.onTap, super.key});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: CustomPaint(
        painter: _DashedStadiumPainter(gb.grey400.withValues(alpha: 0.6)),
        child: SizedBox(
          height: AppSizes.chipHeight - 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gb.grey500),
                child: IconTheme.merge(data: IconThemeData(color: gb.grey500, size: AppSizes.iconSm), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  _DashedStadiumPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.border;
    const dash = 4.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter old) => old.color != color;
}
