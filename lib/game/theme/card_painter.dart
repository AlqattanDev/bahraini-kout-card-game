import 'dart:math' as math;
import 'dart:ui';
import 'geometric_patterns.dart';
import 'kout_theme.dart';

/// High-contrast card rendering with bold corner indices and custom joker.
///
/// Changes from original:
/// - Font: IBMPlexMono (monospace, consistent widths) instead of serif
/// - Corner rank: 16pt (was 11pt), corner suit: 14pt (was 10pt)
/// - Center suit: 32pt (was 28pt)
/// - Card face: pure white (was ivory), border: dark gray (was green/gold)
/// - Face cards (K/Q/J): decorative inner frame accent
/// - Joker: black starburst with "JOKER" / "خلو" text
class CardPainter {
  // ---------------------------------------------------------------------------
  // Card back — unchanged
  // ---------------------------------------------------------------------------

  static void paintBack(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    final outerBorderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, outerBorderPaint);

    final bgPaint = Paint()..color = KoutTheme.cardBack;
    canvas.drawRRect(rrect, bgPaint);

    GeometricPatterns.drawCardBackPattern(canvas, rect);

    final innerRect = Rect.fromLTRB(
      rect.left + 4, rect.top + 4, rect.right - 4, rect.bottom - 4,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(KoutTheme.cardBorderRadius - 1),
    );
    final goldBorderPaint = Paint()
      ..color = KoutTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(innerRRect, goldBorderPaint);
  }

  // ---------------------------------------------------------------------------
  // Card face — high-contrast rewrite
  // ---------------------------------------------------------------------------

  static void paintFace(
    Canvas canvas,
    Rect rect,
    String rankStr,
    String suitSymbol,
    Color suitColor,
  ) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    // Pure white face fill
    canvas.drawRRect(rrect, Paint()..color = KoutTheme.cardFace);

    // Thin dark border (was thick green/gold)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = KoutTheme.cardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Top-left corner: rank (large, bold)
    _drawCardText(
      canvas, rankStr, suitColor,
      Offset(rect.left + 6, rect.top + 5),
      KoutTheme.cardCornerRankSize,
      align: TextAlign.left, width: 30,
    );
    // Top-left corner: suit below rank
    _drawCardText(
      canvas, suitSymbol, suitColor,
      Offset(rect.left + 6, rect.top + 5 + KoutTheme.cardCornerRankSize),
      KoutTheme.cardCornerSuitSize,
      align: TextAlign.left, width: 30,
    );

    // Bottom-right corner (rotated 180°)
    canvas.save();
    canvas.translate(rect.right, rect.bottom);
    canvas.rotate(math.pi);
    _drawCardText(
      canvas, rankStr, suitColor,
      const Offset(6, 5),
      KoutTheme.cardCornerRankSize,
      align: TextAlign.left, width: 30,
    );
    _drawCardText(
      canvas, suitSymbol, suitColor,
      Offset(6, 5 + KoutTheme.cardCornerRankSize),
      KoutTheme.cardCornerSuitSize,
      align: TextAlign.left, width: 30,
    );
    canvas.restore();

    // Large center suit symbol
    _drawCardText(
      canvas, suitSymbol, suitColor,
      Offset(rect.left + rect.width / 2, rect.top + rect.height / 2 - 4),
      KoutTheme.cardCenterSuitSize,
      align: TextAlign.center, width: rect.width,
    );

    // Face card accent frame (K, Q, J only)
    if (rankStr == 'K' || rankStr == 'Q' || rankStr == 'J') {
      _drawFaceCardAccent(canvas, rect, suitColor);
    }
  }

  /// Decorative inner frame on face cards to distinguish from pip cards.
  static void _drawFaceCardAccent(Canvas canvas, Rect rect, Color suitColor) {
    final innerRect = Rect.fromLTRB(
      rect.left + 14, rect.top + 30, rect.right - 14, rect.bottom - 30,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..color = suitColor.withOpacity(0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..color = suitColor.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  // Joker — dramatic starburst design
  // ---------------------------------------------------------------------------

  static void paintJoker(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    // White face
    canvas.drawRRect(rrect, Paint()..color = KoutTheme.cardFace);

    // Dark border (slightly thicker for joker emphasis)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = KoutTheme.jokerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final cx = rect.left + rect.width / 2;
    final cy = rect.top + rect.height / 2;

    // 12-point starburst shape (absolute px — sized for 70x100 card)
    final starPath = Path();
    const points = 12;
    const outerRadius = 22.0;
    const innerRadius = 11.0;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    // Black fill
    canvas.drawPath(starPath, Paint()..color = KoutTheme.jokerColor);

    // White inner circle for contrast
    canvas.drawCircle(
      Offset(cx, cy),
      6,
      Paint()..color = KoutTheme.cardFace,
    );

    // "JOKER" text above starburst
    _drawCardText(
      canvas, 'JOKER', KoutTheme.jokerColor,
      Offset(cx, rect.top + 10),
      8,
      align: TextAlign.center, width: rect.width,
    );

    // "خلو" text below starburst (Khallou)
    _drawCardText(
      canvas, 'خلو', KoutTheme.jokerColor,
      Offset(cx, rect.bottom - 22),
      10,
      align: TextAlign.center, width: rect.width,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static void _drawCardText(
    Canvas canvas,
    String text,
    Color color,
    Offset offset,
    double fontSize, {
    required TextAlign align,
    required double width,
  }) {
    final builder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: align,
        fontSize: fontSize,
        fontFamily: 'IBMPlexMono',
      ),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: width));

    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx = offset.dx - width / 2;
    }
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
  }
}
