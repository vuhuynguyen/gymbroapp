import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../domain/enums.dart';

/// GymBro brand mark — rounded blue gradient tile with a top-left gloss; "GB" or a dumbbell glyph.
class BrandMark extends StatelessWidget {
  const BrandMark(
      {this.size = 40,
      this.radius = AppRadius.sm,
      this.glyph = false,
      super.key});
  final double size;
  final double radius;
  final bool glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: GbColors.heroGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.blueSm,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: const RadialGradient(
                  center: Alignment(-0.5, -0.8),
                  radius: 1.0,
                  colors: [Color(0x47FFFFFF), Colors.transparent],
                  stops: [0, 0.6],
                ),
              ),
            ),
          ),
          Center(
            child: glyph
                ? Icon(Icons.fitness_center,
                    color: Colors.white, size: size * 0.5)
                : Text('GB',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: size * 0.4,
                        letterSpacing: -0.5)),
          ),
        ],
      ),
    );
  }
}

/// Premium avatar — gradient circle with the initial, top-left gloss, and an optional gradient ring.
class Avatar extends StatelessWidget {
  const Avatar(
      {required this.initial, this.size = 40, this.ring = false, super.key});
  final String initial;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final inner = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.heroA, AppPalette.heroB],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.5, -0.8),
                  radius: 1.0,
                  colors: [Color(0x4DFFFFFF), Colors.transparent],
                  stops: [0, 0.6],
                ),
              ),
            ),
          ),
          Center(
            child: Text(initial,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.42)),
          ),
        ],
      ),
    );
    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [gb.primary25, gb.primary500]),
      ),
      child: inner,
    );
  }
}

/// Uppercase, tracked eyebrow label (design `.gb-eyebrow`).
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.color, super.key});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: AppText.eyebrow.copyWith(color: color ?? context.gb.grey400));
}

/// Completion ring with a gradient sweep + optional center content (design `Ring`).
class GbRing extends StatelessWidget {
  const GbRing({
    required this.value,
    this.size = 56,
    this.stroke = 6,
    this.child,
    this.gradient,
    this.trackColor,
    super.key,
  });
  final double value; // 0..1
  final double size;
  final double stroke;
  final Widget? child;
  final List<Color>? gradient;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          colors: gradient ?? [gb.primary500, gb.primary700],
          track: trackColor ?? gb.grey25,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.value,
      required this.stroke,
      required this.colors,
      required this.track});
  final double value;
  final double stroke;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    final ringColors =
        colors.length >= 2 ? colors : [colors.first, colors.first];
    final shader = SweepGradient(
      colors: ringColors,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.track != track ||
      !listEquals(old.colors, colors);
}

/// Weekday/status badge for a session row (design `DayBadge`) — colored by session status.
class DayBadge extends StatelessWidget {
  const DayBadge({required this.label, required this.status, super.key});
  final String label;
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final (bg, fg) = switch (status) {
      SessionStatus.inProgress => (gb.primary0, gb.primary700),
      SessionStatus.completed => (gb.grey25, gb.grey700),
      SessionStatus.abandoned => (gb.danger0, gb.danger),
    };
    return Container(
      width: AppSizes.dayBadge,
      height: AppSizes.dayBadge,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brBadge),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}

/// Weight/reps stepper (design `Stepper`). Stateless — the parent owns the value.
class GbStepper extends StatelessWidget {
  const GbStepper({
    required this.value,
    required this.onChanged,
    this.unit,
    this.step = 1,
    this.label,
    this.semanticLabel,
    super.key,
  });

  final num value;
  final ValueChanged<num> onChanged;
  final String? unit;
  final num step;
  final String? label;

  /// Screen-reader name for the measure (e.g. "Weight", "Reps"). The stepper announces
  /// `name value unit` and labels its ± buttons (design a11y §). Defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final display = value is int || value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    final name = semanticLabel ?? label ?? 'value';
    final announced = '$name $display${unit != null ? ' $unit' : ''}';
    return Column(
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(label!,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: gb.grey400)),
          ),
        // Constant-width [−][value][+] group: fixed buttons + a fixed value slot whose number scales to fit.
        // No outer scaling, so every stepper is the same size and the ± buttons line up across rows/columns,
        // and the layout never shifts as the value changes.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(gb, Icons.remove, 'Decrease $name',
                () => onChanged((value - step).clamp(0, 100000))),
            const SizedBox(width: 6),
            Semantics(
              label: announced,
              excludeSemantics: true,
              child: SizedBox(
                width: 58,
                height: 34,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(display,
                          style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)
                              .tabular),
                      if (unit != null)
                        Text(' $unit',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: gb.grey400)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _btn(gb, Icons.add, 'Increase $name',
                () => onChanged(value + step)),
          ],
        ),
      ],
    );
  }

  Widget _btn(GbColors gb, IconData icon, String semanticLabel,
          VoidCallback onTap) =>
      Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: gb.grey0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: gb.borderCard, width: AppSizes.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: SizedBox(
                width: AppSizes.stepperButton,
                height: AppSizes.stepperButton,
                child: Icon(icon, size: AppSizes.iconXl, color: gb.grey700)),
          ),
        ),
      );
}
