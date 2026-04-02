import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/geometric_patterns.dart';
import '../theme/kout_theme.dart';

/// Renders subtle Diwaniya ambient decorations:
/// - A tea glass (istikana) silhouette near each player seat
/// - A geometric pattern overlay on the background at low opacity
///
/// All decorations are drawn at very low opacity (5–10%) to remain unobtrusive.
class AmbientDecorationComponent extends PositionComponent {
  /// Seat positions (absolute, in game coordinates) where tea glasses appear.
  final List<Vector2> seatPositions;

  AmbientDecorationComponent({required this.seatPositions})
      : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    // 1. Geometric overlay at 8% opacity
    GeometricPatterns.drawStarTessellation(
      canvas,
      Rect.fromLTWH(0, 0, size.x, size.y),
      opacity: 0.08,
      cellSize: 48.0,
    );

    // 2. Tea glass (istikana) silhouette near each seat
    for (final pos in seatPositions) {
      _drawIstikana(canvas, pos);
    }
  }

  /// Draws a simple istikana (tea glass) silhouette at [seatPos].
  ///
  /// The glass is offset slightly from the seat center and rendered at ~8% opacity.
  void _drawIstikana(Canvas canvas, Vector2 seatPos) {
    // Offset to the lower-right of the seat, out of the way
    final cx = seatPos.x + 50.0;
    final cy = seatPos.y + 45.0;

    const opacity = 0.25;
    final glassColor = KoutTheme.accent.withValues(alpha: opacity);
    final liquidColor = const Color(0xFFCC6600).withValues(alpha: opacity * 0.8);

    final paint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.fill;

    // Glass body — trapezoid shape (wider at top, narrower at bottom)
    final bodyPath = Path();
    const halfTopW = 8.0;
    const halfBotW = 5.0;
    const glassH = 14.0;
    bodyPath.moveTo(cx - halfTopW, cy);
    bodyPath.lineTo(cx + halfTopW, cy);
    bodyPath.lineTo(cx + halfBotW, cy + glassH);
    bodyPath.lineTo(cx - halfBotW, cy + glassH);
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);

    // Rim line at the top
    final rimPaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(cx - halfTopW - 1, cy),
      Offset(cx + halfTopW + 1, cy),
      rimPaint,
    );

    // Tea liquid fill (slightly darker, ~60% height of glass)
    final liquidPath = Path();
    const fillH = glassH * 0.6;
    const fillTopW = halfTopW * 0.95;
    final fillBotW = halfBotW + (halfTopW - halfBotW) * (1 - fillH / glassH);
    liquidPath.moveTo(cx - fillTopW, cy + (glassH - fillH));
    liquidPath.lineTo(cx + fillTopW, cy + (glassH - fillH));
    liquidPath.lineTo(cx + fillBotW, cy + glassH);
    liquidPath.lineTo(cx - fillBotW, cy + glassH);
    liquidPath.close();
    canvas.drawPath(liquidPath, Paint()..color = liquidColor);

    // Small handle on the right
    final handlePaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final handleRect = Rect.fromLTWH(
      cx + halfBotW,
      cy + glassH * 0.3,
      4.0,
      glassH * 0.4,
    );
    canvas.drawArc(handleRect, -math.pi / 2, math.pi, false, handlePaint);

    // Saucer ellipse at the bottom
    final saucerPaint = Paint()
      ..color = glassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + glassH + 2),
        width: halfTopW * 2.2,
        height: 3.0,
      ),
      saucerPaint,
    );
  }
}
