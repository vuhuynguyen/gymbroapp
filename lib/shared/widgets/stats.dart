import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'cards.dart';

/// KPI stat tile (design `StatTile`) — icon, big tabular value (+optional unit), eyebrow label.
/// Designed to sit in a `Row` of `Expanded`s.
class GbStatTile extends StatelessWidget {
  const GbStatTile({required this.value, required this.label, this.icon, this.unit, this.accent, super.key});
  final String value;
  final String label;
  final IconData? icon;
  final String? unit;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return GbCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconLg, color: accent ?? gb.grey400),
            const SizedBox(height: AppSpacing.xs + 1),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(value, style: AppText.statNumber.copyWith(fontSize: 23), overflow: TextOverflow.ellipsis)),
              if (unit != null)
                Text(' $unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gb.grey400)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppText.eyebrow.copyWith(color: gb.grey400)),
        ],
      ),
    );
  }
}

/// Section heading (design 14px / 800 ink title), with an optional muted count suffix.
class GbSectionTitle extends StatelessWidget {
  const GbSectionTitle(this.text, {this.count, super.key});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    if (count == null) return Text(text, style: AppText.sectionTitle);
    return Text.rich(TextSpan(children: [
      TextSpan(text: text, style: AppText.sectionTitle),
      TextSpan(text: ' · $count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: gb.grey400)),
    ]));
  }
}
