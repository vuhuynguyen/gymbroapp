import 'package:flutter/widgets.dart';

/// Animation timing tokens — mirror the prototype's transitions (press .12s, indicators .2s,
/// sheet .32s cubic-bezier, ring .6s). Centralized so motion feels consistent app-wide.
abstract final class AppDurations {
  AppDurations._();

  /// 120ms — press/tap feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// 200ms — chip/indicator/chevron state changes.
  static const Duration base = Duration(milliseconds: 200);

  /// 320ms — bottom-sheet slide.
  static const Duration slow = Duration(milliseconds: 320);

  /// 600ms — completion-ring sweep.
  static const Duration ring = Duration(milliseconds: 600);
}

/// Reduced-motion accessor (design Motion §: "Respect reduced motion … drop the entrance slides
/// and the pulse; show end states immediately"). Flutter surfaces the OS "reduce motion" /
/// "remove animations" setting through [MediaQueryData.disableAnimations]. Gate infinite loops
/// (the live-dot pulse, skeleton shimmer) and entrance animations on this — render the steady end
/// state instead of animating.
extension MotionContext on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
