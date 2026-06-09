import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';

/// Renders an [AsyncValue] as loading (skeleton or spinner) / error(retry) / data. The single async
/// surface used by every screen — swap the visuals here, not at call sites.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({required this.value, required this.data, this.onRetry, this.loading, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Future<void> Function()? onRetry;

  /// Optional custom loading widget (e.g. a tailored skeleton); defaults to a centered spinner.
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => loading ?? const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          message: e is ApiException ? e.message : 'Something went wrong.',
          onRetry: onRetry,
        ),
      );
}

/// Centered error state with a retry action.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.message, this.onRetry, super.key});
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: gb.danger0, borderRadius: AppRadius.brMd),
              child: Icon(Icons.error_outline, size: AppSizes.iconXxl, color: gb.danger),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: gb.grey600)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              GbButton(label: 'Retry', icon: Icons.refresh, variant: GbButtonVariant.outlined, severity: GbButtonSeverity.secondary, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered empty state — soft icon tile, title, optional subtitle and action. Pass [onTap] to make
/// the icon tile itself a button (e.g. the live-session "No exercises yet" → add an exercise).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.onTap,
    this.tapLabel,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// Makes the icon tile tappable (primary-tinted to signal it's actionable).
  final VoidCallback? onTap;

  /// a11y label for the tappable icon (design a11y §) — required-in-spirit when [onTap] is set.
  final String? tapLabel;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final actionable = onTap != null;
    Widget iconTile = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: actionable ? gb.primary0 : gb.grey0,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: actionable ? gb.primary50 : gb.borderCard),
      ),
      child: Icon(icon, size: 30, color: actionable ? gb.primary500 : gb.grey400),
    );
    if (actionable) {
      iconTile = Semantics(
        button: true,
        label: tapLabel ?? title,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brLg,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: iconTile),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconTile,
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppText.rowTitle.copyWith(fontSize: 16), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: TextStyle(color: gb.grey500), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.md + 2), action!],
          ],
        ),
      ),
    );
  }
}

/// A single shimmering skeleton block (pulse animation). Use for loading placeholders.
class GbSkeleton extends StatefulWidget {
  const GbSkeleton({this.width, this.height = 16, this.radius = AppRadius.sm, super.key});
  final double? width;
  final double height;
  final double radius;

  @override
  State<GbSkeleton> createState() => _GbSkeletonState();
}

class _GbSkeletonState extends State<GbSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor reduced motion (design Motion §): hold a steady mid-opacity placeholder instead of
    // the infinite shimmer.
    if (context.reduceMotion) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: gb.grey25, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// A list of skeleton "cards" approximating loading rows (e.g. the Log timeline / Plan list).
class GbSkeletonList extends StatelessWidget {
  const GbSkeletonList({this.count = 4, this.itemHeight = 68, this.padding = const EdgeInsets.all(AppSpacing.screenH), super.key});
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (_, __) => GbSkeleton(height: itemHeight, radius: AppRadius.md),
    );
  }
}

/// One-shot error snackbar helper used after imperative actions.
void showErrorSnack(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'Something went wrong.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
