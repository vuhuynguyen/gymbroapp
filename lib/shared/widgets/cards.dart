import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Standard content card — white surface, hairline border, design card shadow, radius-16. The
/// base building block; pass [onTap] to make it tappable, [dashed] for "add" affordances.
class GbCard extends StatelessWidget {
  const GbCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.onTap,
    this.radius = AppRadius.md,
    this.dashed = false,
    this.color,
    this.border,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool dashed;
  final Color? color;
  final Color? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final br = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);

    if (dashed) {
      return _DashedBorder(
        radius: radius,
        color: border ?? gb.borderField,
        child: Material(
          color: color ?? gb.card,
          borderRadius: br,
          child: onTap == null
              ? content
              : InkWell(borderRadius: br, onTap: onTap, child: content),
        ),
      );
    }

    // Explicit white fill via DecoratedBox (so the card is unambiguously white, never a grey tint),
    // a crisp soft shadow to lift it off the canvas, and a ClipRRect so the ripple stays rounded.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? gb.card,
        borderRadius: br,
        border: Border.all(color: border ?? gb.borderCard),
        boxShadow: shadow ? AppShadows.sm : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );
  }
}

/// A [GbCard] whose body collapses behind a tappable header with a rotating chevron. The [header]
/// stays visible (build it to read well collapsed — e.g. title + a count summary); tapping toggles
/// [child]. Defaults to collapsed ([initiallyExpanded] = false), which keeps long exercise/set lists
/// scannable. Pass [trailing] for widgets that sit before the chevron (PR chip, status badge).
class GbCollapsibleCard extends StatefulWidget {
  const GbCollapsibleCard({
    required this.header,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
    super.key,
  });

  final Widget header;
  final Widget child;
  final List<Widget>? trailing;
  final bool initiallyExpanded;

  @override
  State<GbCollapsibleCard> createState() => _GbCollapsibleCardState();
}

class _GbCollapsibleCardState extends State<GbCollapsibleCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(child: widget.header),
                if (widget.trailing != null) ...[
                  for (final t in widget.trailing!) ...[
                    const SizedBox(width: AppSpacing.xs - 1),
                    t,
                  ],
                ],
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: AppDurations.base,
                  child: Icon(Icons.chevron_right,
                      size: AppSizes.iconMd, color: gb.grey400),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppDurations.base,
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
                    child: SizedBox(width: double.infinity, child: widget.child),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Blue gradient hero container (design hero cards on Log / Plan, live header surface).
class GbHeroCard extends StatelessWidget {
  const GbHeroCard({required this.child, this.padding = const EdgeInsets.all(AppSpacing.heroPad), this.radius = AppRadius.lg, super.key});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: GbColors.heroGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.blue,
      ),
      child: child,
    );
  }
}

/// Rounded-square icon container used inside list rows (the colored tile holding an icon/number).
class GbIconTile extends StatelessWidget {
  const GbIconTile({
    required this.child,
    this.size = 42,
    this.background,
    this.radius = AppRadius.sm,
    super.key,
  });
  final Widget child;
  final double size;
  final Color? background;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? context.gb.primary0,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Reusable tappable list row — `[leading]  title / subtitle  [trailing]`. Backs the start-sheet
/// assignment cards, profile menu, catalog rows, substitute rows, PR rows, and plan exercise rows.
/// Use [dashed] for the ad-hoc/add variant; trailing defaults to a chevron.
class GbTappableRow extends StatelessWidget {
  const GbTappableRow({
    required this.title,
    this.subtitle,
    this.titleTrailing,
    this.leading,
    this.trailing = const Icon(Icons.chevron_right),
    this.onTap,
    this.dashed = false,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Inline widget placed right of the title (e.g. a visibility badge / source tag).
  final Widget? titleTrailing;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dashed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      onTap: onTap,
      dashed: dashed,
      shadow: !dashed,
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: AppText.rowTitle)),
                    if (titleTrailing != null) ...[const SizedBox(width: AppSpacing.xs - 1), titleTrailing!],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.meta.copyWith(color: gb.grey500)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconTheme.merge(
              data: IconThemeData(color: gb.grey400, size: AppSizes.iconLg),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints a dashed rounded-rect border around [child] (Flutter has no native dashed border).
class _DashedBorder extends StatelessWidget {
  const _DashedBorder({required this.child, required this.radius, required this.color});
  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedRectPainter(radius: radius, color: color), child: child);
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.radius, required this.color});
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.border;
    const dash = 5.0, gap = 4.0;
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
  bool shouldRepaint(_DashedRectPainter old) => old.color != color || old.radius != radius;
}
