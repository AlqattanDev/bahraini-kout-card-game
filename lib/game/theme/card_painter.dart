import 'dart:ui';
import 'package:flutter/painting.dart' show BorderRadius, RRect, TextAlign;
import '../theme/geometric_patterns.dart';
import '../theme/kout_theme.dart';

/// Procedural card rendering with Diwaniya theme.
///
/// Provides static methods to paint card backs and faces onto a [Canvas].
class CardPainter {
  // ---------------------------------------------------------------------------
  // Card back
  // ---------------------------------------------------------------------------

  /// Paints a themed card back with Islamic geometric decoration.
  ///
  /// Layout: white outer border → burgundy fill → geometric star pattern →
  /// gold inner border line.
  static void paintBack(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    // White outer border
    final outerBorderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, outerBorderPaint);

    // Burgundy fill
    final bgPaint = Paint()..color = KoutTheme.cardBack;
    canvas.drawRRect(rrect, bgPaint);

    // Geometric pattern
    GeometricPatterns.drawCardBackPattern(canvas, rect);

    // Gold inner border line
    final innerRect = Rect.fromLTRB(
      rect.left + 4,
      rect.top + 4,
      rect.right - 4,
      rect.bottom - 4,
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
  // Card face
  // ---------------------------------------------------------------------------

  /// Paints a themed card face.
  ///
  /// Layout: ivory fill → outer border → rank+suit top-left →
  /// rank+suit bottom-right (rotated) → large center suit symbol.
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

    // Ivory face fill
    final facePaint = Paint()..color = KoutTheme.cardFace;
    canvas.drawRRect(rrect, facePaint);

    // Outer border
    final borderPaint = Paint()
      ..color = KoutTheme.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // Top-left: rank
    _drawCardText(canvas, rankStr, suitColor, const Offset(8, 8), 11,
        align: TextAlign.left, width: KoutTheme.cardWidth);
    // Top-left: suit below rank
    _drawCardText(canvas, suitSymbol, suitColor, const Offset(8, 20), 10,
        align: TextAlign.left, width: KoutTheme.cardWidth);

    // Bottom-right (rotated 180°)
    canvas.save();
    canvas.translate(KoutTheme.cardWidth, KoutTheme.cardHeight);
    canvas.rotate(3.14159);
    _drawCardText(canvas, rankStr, suitColor, const Offset(8, 8), 11,
        align: TextAlign.left, width: KoutTheme.cardWidth);
    _drawCardText(canvas, suitSymbol, suitColor, const Offset(8, 20), 10,
        align: TextAlign.left, width: KoutTheme.cardWidth);
    canvas.restore();

    // Large center suit symbol
    _drawCardText(
      canvas,
      suitSymbol,
      suitColor,
      Offset(KoutTheme.cardWidth / 2, KoutTheme.cardHeight / 2),
      28,
      align: TextAlign.center,
      width: KoutTheme.cardWidth,
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
        fontFamily: 'serif',
      ),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: width));

    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx = offset.dx - paragraph.maxIntrinsicWidth / 2;
    }
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
  }
}
