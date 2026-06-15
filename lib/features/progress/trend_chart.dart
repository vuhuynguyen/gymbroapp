import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/progress_models.dart';
import 'progress_format.dart';

/// The e1RM CustomPaint trend chart shared by the trainee per-lift drill-down (Phase 2a) and the
/// coach per-client strength detail (Phase 2b). Both surfaces plot the SAME [E1rmSeriesPoint] series
/// — the trainee's via the self-scoped `/api/me/exercises/{id}/e1rm-series`, the coach's via the
/// tenant-scoped `/api/clients/{id}/progress/strength`. Hand-rolled `CustomPaint` (Decision D11 — no
/// chart library).
///
/// Faint raw session points, a bold lightly-anchored e1RM line (only above the 4-point honesty gate),
/// amber PR dots where `isPr`, and min/max y labels. Below the gate it plots only the raw dots — the
/// caller shows the "log N more" copy; a line under the gate is a fabricated signal.
/// Default plotted value: the session-best e1RM.
double e1rmValue(E1rmSeriesPoint p) => p.sessionBestE1rmKg;

/// Alternate plotted value: the top working-set weight that session (null → 0).
double weightValue(E1rmSeriesPoint p) => p.topSetWeightKg ?? 0;

class TrendChart extends StatelessWidget {
  const TrendChart({
    required this.points,
    required this.hasTrend,
    required this.line,
    required this.raw,
    required this.pr,
    required this.label,
    this.valueOf = e1rmValue,
    this.metricId = 'e1rm',
    super.key,
  });

  /// Session-best points, oldest → newest.
  final List<E1rmSeriesPoint> points;

  /// Which value to plot per point (e1RM by default, or top-set weight). [metricId] identifies it so
  /// the painter repaints when the user switches metric.
  final double Function(E1rmSeriesPoint) valueOf;
  final String metricId;

  /// Whether the 4-point honesty gate is cleared — gates the connecting line on/off.
  final bool hasTrend;

  /// The e1RM line colour (direction-tinted by the caller).
  final Color line;

  /// Faint raw-point colour.
  final Color raw;

  /// Amber PR-marker colour.
  final Color pr;

  /// Min/max axis-label colour.
  final Color label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TrendPainter(
        points: points,
        hasTrend: hasTrend,
        line: line,
        raw: raw,
        pr: pr,
        label: label,
        valueOf: valueOf,
        metricId: metricId,
      ),
      size: Size.infinite,
    );
  }
}

/// The painter behind [TrendChart]. Public so the chart can be reused and tested across surfaces.
class TrendPainter extends CustomPainter {
  TrendPainter({
    required this.points,
    required this.hasTrend,
    required this.line,
    required this.raw,
    required this.pr,
    required this.label,
    this.valueOf = e1rmValue,
    this.metricId = 'e1rm',
  });
  final List<E1rmSeriesPoint> points;
  final bool hasTrend;
  final Color line;
  final Color raw;
  final Color pr;
  final Color label;
  final double Function(E1rmSeriesPoint) valueOf;
  final String metricId;

  /// The plotted values (e1RM or weight) — depends only on the (immutable) [points] + selector, so
  /// mapped once per painter instance instead of on every `paint`.
  late final List<double> _values = [for (final p in points) valueOf(p)];

  /// Axis bounds (min, max, span) over [_values] — likewise input-only, so derived once. Empty for an
  /// empty series (paint early-returns before reading them).
  late final (double, double, double) _bounds = _computeBounds();

  /// Min/max/span over the plotted values, padding a flat (or near-flat) series so the line isn't
  /// pinned to an edge.
  (double, double, double) _computeBounds() {
    if (_values.isEmpty) return (0, 0, 0);
    var minV = _values.reduce(math.min);
    var maxV = _values.reduce(math.max);
    if ((maxV - minV).abs() < 1e-6) {
      final pad = maxV.abs() < 1e-6 ? 1.0 : maxV.abs() * 0.05;
      minV -= pad;
      maxV += pad;
    }
    return (minV, maxV, maxV - minV);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = _values;
    final (minV, maxV, span) = _bounds;

    // Reserve a left gutter for the min/max y labels and a little top/bottom breathing room.
    const leftGutter = 34.0;
    const topPad = 10.0;
    const bottomPad = 10.0;
    final plotLeft = leftGutter;
    final plotRight = size.width;
    final plotW = (plotRight - plotLeft).clamp(1.0, double.infinity);
    final plotTop = topPad;
    final plotH = (size.height - topPad - bottomPad).clamp(1.0, double.infinity);

    final n = points.length;
    double x(int i) => n == 1 ? plotLeft + plotW / 2 : plotLeft + plotW * (i / (n - 1));
    double y(double v) => plotTop + plotH - ((v - minV) / span) * plotH;

    // Y-axis min/max labels (non-zero, honest — the axis is bounded to the data range).
    _drawLabel(canvas, fmtKg(maxV), Offset(0, plotTop), label);
    _drawLabel(canvas, fmtKg(minV), Offset(0, plotTop + plotH - 9), label);

    // Bold e1RM line — only above the 4-point honesty gate.
    if (hasTrend) {
      final path = Path()..moveTo(x(0), y(values[0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(x(i), y(values[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Faint raw session points behind the markers.
    final rawPaint = Paint()..color = raw.withValues(alpha: 0.55);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 2.2, rawPaint);
    }

    // Amber PR markers — points where the session-best set a new running max.
    final prFill = Paint()..color = pr;
    final prRing = Paint()
      ..color = pr.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      if (!points[i].isPr) continue;
      final c = Offset(x(i), y(values[i]));
      canvas.drawCircle(c, 6.5, prRing);
      canvas.drawCircle(c, 3.6, prFill);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 32);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(TrendPainter old) =>
      old.metricId != metricId ||
      old.hasTrend != hasTrend ||
      old.line != line ||
      old.raw != raw ||
      old.pr != pr ||
      old.label != label ||
      !_samePoints(old.points, points);
}

bool _samePoints(List<E1rmSeriesPoint> a, List<E1rmSeriesPoint> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].sessionBestE1rmKg != b[i].sessionBestE1rmKg || a[i].isPr != b[i].isPr) {
      return false;
    }
  }
  return true;
}
