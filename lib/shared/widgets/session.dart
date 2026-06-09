import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/enums.dart';
import 'cards.dart';
import 'chips_badges.dart';
import 'foundation.dart';

/// Session timeline row (design `SessionRow`) — used by the Workout Log and the coach Client
/// Monitor. Day badge + name + source tag + status note, a meta line (time · duration · volume),
/// and a trailing column (PR chip / RPE / chevron). Display strings are passed in so the row stays
/// decoupled from any specific model.
class GbSessionRow extends StatelessWidget {
  const GbSessionRow({
    required this.day,
    required this.status,
    required this.title,
    required this.source,
    this.relativeTime,
    this.durationLabel,
    this.volumeLabel,
    this.prCount = 0,
    this.rpe,
    this.onTap,
    super.key,
  });

  final String day;
  final SessionStatus status;
  final String title;
  final SessionSource source;
  final String? relativeTime;
  final String? durationLabel;
  final String? volumeLabel;
  final int prCount;
  final int? rpe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;

    final statusNote = switch (status) {
      SessionStatus.abandoned => ('· stopped early', gb.warning200),
      SessionStatus.inProgress => ('· live', gb.primary600),
      SessionStatus.completed => (null, gb.grey500),
    };

    final meta = <Widget>[
      if (relativeTime != null) Text(relativeTime!, style: AppText.meta.copyWith(color: gb.grey500)),
      if (durationLabel != null) _metaIcon(gb, Icons.schedule, durationLabel!),
      if (volumeLabel != null) _metaIcon(gb, Icons.bar_chart, volumeLabel!),
    ];

    // Reuse GbCard so the row is the same crisp white DecoratedBox as the rest of the cards (a raw
    // Material can pick up an M3 surface tint and read as grey).
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GbCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            DayBadge(label: day, status: status),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: AppText.rowTitle.copyWith(color: gb.grey900)),
                      SourceTag(source, small: true),
                      if (statusNote.$1 != null)
                        Text(statusNote.$1!,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusNote.$2)),
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(spacing: AppSpacing.sm, runSpacing: 2, children: meta),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (prCount > 0) ...[const PrChip(small: true), const SizedBox(height: 5)],
                if (rpe != null) ...[
                  Text('RPE $rpe', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gb.grey400)),
                  const SizedBox(height: 5),
                ],
                Icon(Icons.chevron_right, size: AppSizes.iconMd, color: gb.grey400),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaIcon(GbColors gb, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconXs, color: gb.grey500),
          const SizedBox(width: 3),
          Text(text, style: AppText.meta.copyWith(color: gb.grey500)),
        ],
      );
}

/// A "weight×reps" set pill used in the Session Detail breakdown — amber-highlighted for a PR set.
class GbSetPill extends StatelessWidget {
  const GbSetPill({required this.label, this.isPr = false, super.key});
  final String label;
  final bool isPr;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPr ? gb.amberSoft : gb.grey0,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: isPr ? gb.amber.withValues(alpha: 0.4) : gb.borderCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPr) ...[Icon(Icons.emoji_events, size: AppSizes.iconXs, color: gb.amber), const SizedBox(width: 4)],
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isPr ? gb.amberInk : gb.grey700).tabular),
        ],
      ),
    );
  }
}
