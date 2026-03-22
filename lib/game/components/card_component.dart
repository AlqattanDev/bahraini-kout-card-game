import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show BorderRadius, RRect;
import '../../shared/models/card.dart';
import '../../shared/models/enums.dart';
import '../theme/kout_theme.dart';

/// A Flame component that renders a single playing card.
///
/// Renders face-up or face-down. Supports tap callbacks.
class CardComponent extends PositionComponent with TapCallbacks {
  GameCard? card;
  bool isFaceUp;
  bool isHighlighted;
  final void Function(GameCard card)? onTap;

  CardComponent({
    this.card,
    this.isFaceUp = true,
    this.isHighlighted = false,
    this.onTap,
    super.position,
    super.angle,
    super.anchor = Anchor.center,
  }) : super(
          size: Vector2(KoutTheme.cardWidth, KoutTheme.cardHeight),
        );

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    if (isFaceUp && card != null) {
      _renderFaceUp(canvas, rect, rrect);
    } else {
      _renderFaceDown(canvas, rrect);
    }
  }

  void _renderFaceDown(Canvas canvas, RRect rrect) {
    // Background
    final bgPaint = Paint()..color = KoutTheme.cardBack;
    canvas.drawRRect(rrect, bgPaint);

    // Gold border
    final borderPaint = Paint()
      ..color = KoutTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // Inner decorative border
    final innerRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(4, 4, KoutTheme.cardWidth - 4, KoutTheme.cardHeight - 4),
      const Radius.circular(KoutTheme.cardBorderRadius - 1),
    );
    canvas.drawRRect(innerRRect, borderPaint);
  }

  void _renderFaceUp(Canvas canvas, Rect rect, RRect rrect) {
    final c = card!;

    // Background
    final bgPaint = Paint()..color = KoutTheme.cardFace;
    canvas.drawRRect(rrect, bgPaint);

    // Border — gold if highlighted, white otherwise
    final borderColor =
        isHighlighted ? KoutTheme.accent : KoutTheme.cardBorder;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHighlighted ? 2.5 : 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // Greyed-out overlay for non-playable cards
    if (!isHighlighted) {
      final greyPaint = Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.fill;
      // Only apply grey when explicitly not highlighted (caller controls this)
    }

    if (c.isJoker) {
      _drawText(canvas, 'JO', const Color(0xFF800080),
          Offset(KoutTheme.cardWidth / 2, KoutTheme.cardHeight / 2), 20);
      return;
    }

    final isRed =
        c.suit == Suit.hearts || c.suit == Suit.diamonds;
    final suitColor =
        isRed ? const Color(0xFFCC0000) : const Color(0xFF111111);

    final rankLabel = _rankLabel(c.rank!);
    final suitSymbol = _suitSymbol(c.suit!);

    // Top-left rank + suit
    _drawText(canvas, rankLabel, suitColor, const Offset(8, 8), 11,
        align: TextAlign.left);
    _drawText(canvas, suitSymbol, suitColor, const Offset(8, 20), 10,
        align: TextAlign.left);

    // Bottom-right rank + suit (rotated 180°)
    canvas.save();
    canvas.translate(KoutTheme.cardWidth, KoutTheme.cardHeight);
    canvas.rotate(3.14159);
    _drawText(canvas, rankLabel, suitColor, const Offset(8, 8), 11,
        align: TextAlign.left);
    _drawText(canvas, suitSymbol, suitColor, const Offset(8, 20), 10,
        align: TextAlign.left);
    canvas.restore();

    // Large center suit symbol
    _drawText(
      canvas,
      suitSymbol,
      suitColor,
      Offset(KoutTheme.cardWidth / 2, KoutTheme.cardHeight / 2),
      28,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Color color,
    Offset offset,
    double fontSize, {
    TextAlign align = TextAlign.center,
  }) {
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        textAlign: align,
        fontSize: fontSize,
        fontFamily: 'serif',
      ),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ParagraphConstraints(width: KoutTheme.cardWidth));

    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx = offset.dx - paragraph.maxIntrinsicWidth / 2;
    }
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy));
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isFaceUp && card != null && onTap != null) {
      onTap!(card!);
    }
  }

  String _rankLabel(Rank rank) {
    const labels = {
      Rank.ace: 'A',
      Rank.king: 'K',
      Rank.queen: 'Q',
      Rank.jack: 'J',
      Rank.ten: '10',
      Rank.nine: '9',
      Rank.eight: '8',
      Rank.seven: '7',
    };
    return labels[rank] ?? '?';
  }

  String _suitSymbol(Suit suit) {
    const symbols = {
      Suit.spades: '♠',
      Suit.hearts: '♥',
      Suit.clubs: '♣',
      Suit.diamonds: '♦',
    };
    return symbols[suit] ?? '?';
  }
}
