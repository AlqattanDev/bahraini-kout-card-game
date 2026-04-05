import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/rendering.dart' show CustomPainter;
import 'kout_theme.dart';

/// Procedural Islamic geometric pattern renderer.
///
/// Draws a repeating 8-point star tessellation using rotational symmetry.
/// Uses [KoutTheme.cardBack] as fill and [KoutTheme.accent] as stroke
/// to stay consistent with card-back art.
class GeometricPatterns {
  // Opacity multipliers for star patterns
  static const double _fillOpacity = 0.6;
  static const double _strokeOpacity = 0.5;

  /// Draws a repeating 8-point star pattern tiled across [bounds].
  ///
  /// [opacity] controls the overall translucency (0.0–1.0).
  static void drawStarTessellation(
    Canvas canvas,
    Rect bounds, {
    double opacity = 1.0,
    double cellSize = 40.0,
  }) {
    canvas.save();
    canvas.clipRect(bounds);
    canvas.translate(bounds.left, bounds.top);

    final width = bounds.width;
    final height = bounds.height;

    // Tile the pattern across the bounds
    final cols = (width / cellSize).ceil() + 1;
    final rows = (height / cellSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * cellSize + (row.isOdd ? cellSize / 2 : 0);
        final cy = row * cellSize;
        _drawEightPointStar(
          canvas,
          Offset(cx, cy),
          cellSize * 0.38,
          opacity,
        );
      }
    }

    canvas.restore();
  }

  /// Draws a single 8-point star centered at [center] with outer [radius].
  static void _drawEightPointStar(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
  ) {
    const points = 8;
    const angleStep = math.pi * 2 / points;
    const innerRatio = 0.45; // inner radius as fraction of outer

    final outerRadius = radius;
    final innerRadius = radius * innerRatio;

    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = i * angleStep / 2 - math.pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill with burgundy
    final fillPaint = Paint()
      ..color = KoutTheme.cardBack.withValues(alpha: opacity * _fillOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Stroke with gold
    final strokePaint = Paint()
      ..color = KoutTheme.accent.withValues(alpha: opacity * _strokeOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(path, strokePaint);
  }

  /// Draws a compact 8-point star pattern for the card back decoration.
  ///
  /// Fills [bounds] with a single-tile star centered in the rect.
  static void drawCardBackPattern(Canvas canvas, Rect bounds) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final maxRadius = math.min(bounds.width, bounds.height) * 0.35;

    // Outer decorative ring
    const rings = 3;
    for (int ring = rings; ring >= 1; ring--) {
      final r = maxRadius * ring / rings;
      _drawEightPointStar(canvas, Offset(cx, cy), r, 0.8);
    }

    // Small stars in corners
    final cornerOffset = maxRadius * 0.55;
    for (final offset in [
      Offset(cx - cornerOffset, cy - cornerOffset),
      Offset(cx + cornerOffset, cy - cornerOffset),
      Offset(cx - cornerOffset, cy + cornerOffset),
      Offset(cx + cornerOffset, cy + cornerOffset),
    ]) {
      _drawEightPointStar(canvas, offset, maxRadius * 0.18, 0.5);
    }
  }

  /// Returns a [CustomPainter] that draws the star tessellation at [opacity].
  /// Use in `CustomPaint(painter: GeometricPatterns.overlayPainter(...))`.
  static CustomPainter overlayPainter({double opacity = 0.08}) =>
      _StarOverlayPainter(opacity: opacity);
}

/// Shared CustomPainter adapter for GeometricPatterns.drawStarTessellation.
class _StarOverlayPainter extends CustomPainter {
  const _StarOverlayPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    GeometricPatterns.drawStarTessellation(
      canvas,
      Rect.fromLTWH(0, 0, size.width, size.height),
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(_StarOverlayPainter old) => old.opacity != opacity;
}
