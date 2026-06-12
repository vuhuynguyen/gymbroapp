import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'foundation.dart';

/// Plain sticky screen header (design `PlainHeader`) — a white bar with a large title, optional
/// subtitle, and an optional trailing action. Clears the status bar via [SafeArea].
class GbScreenHeader extends StatelessWidget {
  const GbScreenHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.dense = false,
    super.key,
  });
  final String title;
  final String? subtitle;

  /// Small grey label rendered ABOVE the title (e.g. the coach workspace name).
  final String? eyebrow;
  final Widget? trailing;

  /// Coach-tab sizing — a 19px title (vs the 23px trainee `PlainHeader`).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final titleStyle = dense
        ? AppText.screenTitle
            .copyWith(fontSize: 19, letterSpacing: -0.1, color: gb.ink)
        : AppText.screenTitle.copyWith(color: gb.ink);
    return _HeaderSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 2, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm + 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow != null) ...[
                    Text(eyebrow!,
                        style: TextStyle(fontSize: 12, color: gb.grey500),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                  ],
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 13, color: gb.grey500)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Unified main-tab header (the Log header style, applied everywhere for consistency): the GymBro
/// brand mark (matching the login screen), the page title, and optional trailing actions (streak
/// chip, notification bell). No greeting.
class GbAppHeader extends StatelessWidget {
  const GbAppHeader(
      {required this.title, this.subtitle, this.actions = const [], super.key});
  final String title;

  /// Optional muted line under the title (e.g. the coach workspace name on the Coach hub).
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return _HeaderSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 2, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm + 1),
        child: Row(
          children: [
            const BrandMark(size: 40, radius: 13, glyph: true),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: gb.ink)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: gb.grey500)),
                ],
              ),
            ),
            for (final a in actions) ...[
              const SizedBox(width: AppSpacing.xs),
              a
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen detail header (design Session Detail / Client Monitor) — a circular leading button
/// (back chevron or X), a centered/leading title, and an optional trailing action button.
class GbDetailHeader extends StatelessWidget {
  const GbDetailHeader({
    required this.title,
    required this.onLeading,
    this.leadingIcon = Icons.chevron_left,
    this.leadingLabel = 'Back',
    this.trailing,
    super.key,
  });
  final String title;
  final VoidCallback onLeading;
  final IconData leadingIcon;

  /// a11y label for the leading button (design a11y §) — defaults to "Back"; pass "Close" for an X.
  final String leadingLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _HeaderSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            _CircleButton(
                icon: leadingIcon,
                onTap: onLeading,
                semanticLabel: leadingLabel),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800))),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Circular grey icon button used in detail headers.
class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.icon, required this.onTap, required this.semanticLabel});
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: gb.grey0,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: AppSizes.iconXl, color: gb.grey700)),
        ),
      ),
    );
  }
}

/// White header surface with a hairline bottom border, clearing the top safe area.
class _HeaderSurface extends StatelessWidget {
  const _HeaderSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Container(
      decoration: BoxDecoration(
          color: gb.card,
          border: Border(bottom: BorderSide(color: gb.borderCard))),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

/// Notification bell button with an optional unread dot (design Log bell).
class GbBellButton extends StatelessWidget {
  const GbBellButton({required this.onTap, this.hasUnread = false, super.key});
  final VoidCallback onTap;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(Icons.notifications_none, color: gb.grey600),
            visualDensity: VisualDensity.compact,
            tooltip:
                'Notifications', // doubles as the a11y label (design a11y §)
          ),
          if (hasUnread)
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: gb.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: gb.card, width: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}
