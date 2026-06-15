import 'package:flutter/material.dart';

import '../../data/models/progress_models.dart';
import '../../shared/widgets/widgets.dart';
import 'progress_format.dart';

/// The up / flat N× / ↓ slipping tag — the shared strength-direction chip used by the home Strength
/// strip (`_LiftRow`), the trainee per-lift drill-down header, and the coach per-client strength cards.
/// `down` is the only state any of those surfaces renders red (PHASE-1 §5). Takes the three scalars
/// (direction + stall summary) so every call site can feed it directly off whichever DTO it holds
/// ([LiftDirection] on the home strip, [ExerciseE1rmSeries] on the drill-down / coach card).
///
/// Restyled to the Progress "Graphite" **DirTag**: a filled caret glyph (▲ up / ▼ down / – flat) + a
/// mono uppercase label, with **colour on the text only** — no background pill. This is the design's
/// instrument-grade direction tick; the labels stay honest ("Up" / "Slipping" / "Flat N×") because the
/// home strip's [LiftDirection] carries no signed delta to print.
///
/// The caret + label are tinted off the design's honest pos/warn/neg channel via [sparkColor]
/// (up `#157A4A` / flat `#8A6312` / down `#AD3B32`) — the SAME channel the row's sparkline uses — so the
/// tick and the thin chart never disagree within a row. (The shared [tagColor] stays the trend-LINE tint
/// for the drill-down and coach charts and is left untouched.)
class LiftDirectionTag extends StatelessWidget {
  const LiftDirectionTag({
    required this.direction,
    required this.stalled,
    required this.stallSessions,
    super.key,
  });

  final LiftTrendDirection direction;
  final bool stalled;
  final int stallSessions;

  @override
  Widget build(BuildContext context) {
    final gb = context.gb;
    final color = sparkColor(gb, direction);
    final label = switch (direction) {
      LiftTrendDirection.up => 'Up',
      LiftTrendDirection.down => 'Slipping',
      LiftTrendDirection.flat =>
        stalled && stallSessions > 0 ? 'Flat $stallSessions×' : 'Flat',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DirCaret(direction: direction, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          // App font (Inter Tight) + tabular figures, zero tracking — the "Flat N×" / "Up" /
          // "Slipping" tag reads tight and clean on real hardware (no monospace, no caps tracking).
          style: AppText.mono(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0),
          ).copyWith(color: color),
        ),
      ],
    );
  }
}

/// The 12×12 direction caret glyph (design `Caret`): a filled up/down triangle, or a flat dash for the
/// neutral state. Colour matches the [LiftDirectionTag] label — the honest pos / warn / neg channel
/// ([sparkColor]), on stroke only.
class _DirCaret extends StatelessWidget {
  const _DirCaret({required this.direction, required this.color});
  final LiftTrendDirection direction;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(12, 12), painter: _CaretPainter(direction, color));
}

class _CaretPainter extends CustomPainter {
  _CaretPainter(this.direction, this.color);
  final LiftTrendDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (direction == LiftTrendDirection.flat) {
      // A centered dash (design `M2.5 6h7`).
      canvas.drawLine(
        Offset(size.width * 0.21, size.height / 2),
        Offset(size.width * 0.79, size.height / 2),
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    // A filled triangle — apex up for `up` (design `M6 2.5l4 5.5H2z`), apex down for `down`.
    final up = direction == LiftTrendDirection.up;
    final w = size.width, h = size.height;
    final path = Path();
    if (up) {
      path
        ..moveTo(w * 0.5, h * 0.21)
        ..lineTo(w * 0.83, h * 0.67)
        ..lineTo(w * 0.17, h * 0.67)
        ..close();
    } else {
      path
        ..moveTo(w * 0.5, h * 0.79)
        ..lineTo(w * 0.83, h * 0.33)
        ..lineTo(w * 0.17, h * 0.33)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.direction != direction || old.color != color;
}
