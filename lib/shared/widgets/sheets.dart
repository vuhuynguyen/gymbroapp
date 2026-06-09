import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'cards.dart';

/// Show a themed modal bottom sheet (rounded top, drag handle from the theme). [scrollable] makes
/// it height-flexible (`isScrollControlled`) for tall content like catalog pickers.
Future<T?> showGbSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollable,
    backgroundColor: context.gb.card,
    builder: (ctx) => SafeArea(child: builder(ctx)),
  );
}

/// Sheet title block (design sheet header) — bold title + muted subtitle.
class GbSheetHeader extends StatelessWidget {
  const GbSheetHeader({required this.title, this.subtitle, super.key});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: TextStyle(fontSize: 13, color: gb.grey500)),
        ],
      ],
    );
  }
}

/// A sheet action row (design `SheetAction`) — rounded icon tile + label + sub + chevron.
class GbSheetActionTile extends StatelessWidget {
  const GbSheetActionTile({
    required this.icon,
    required this.label,
    this.sub,
    this.onTap,
    this.iconColor,
    super.key,
  });
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GbCard(
        onTap: onTap,
        shadow: false,
        border: Colors.transparent,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            GbIconTile(
              background: gb.grey0,
              child: Icon(icon, size: AppSizes.iconXl, color: iconColor ?? gb.grey700),
            ),
            const SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.rowTitle),
                  if (sub != null) ...[
                    const SizedBox(height: 1),
                    Text(sub!, style: TextStyle(fontSize: 12, color: gb.grey500)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: AppSizes.iconLg, color: gb.grey400),
          ],
        ),
      ),
    );
  }
}
