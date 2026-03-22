import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show RRect;
import '../../shared/models/card.dart';
import '../../shared/models/enums.dart';
import '../theme/card_painter.dart';
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
      CardPainter.paintBack(canvas, rect);
    }
  }

  void _renderFaceUp(Canvas canvas, Rect rect, RRect rrect) {
    final c = card!;

    if (c.isJoker) {
      // Joker: use CardPainter face with special label
      CardPainter.paintFace(canvas, rect, 'JO', '★', const Color(0xFF800080));
      return;
    }

    final isRed = c.suit == Suit.hearts || c.suit == Suit.diamonds;
    final suitColor = isRed ? const Color(0xFFCC0000) : const Color(0xFF111111);
    final rankLabel = _rankLabel(c.rank!);
    final suitSymbol = _suitSymbol(c.suit!);

    CardPainter.paintFace(canvas, rect, rankLabel, suitSymbol, suitColor);

    // Highlight border overlay (gold when highlighted)
    if (isHighlighted) {
      final highlightPaint = Paint()
        ..color = KoutTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(rrect, highlightPaint);
    }
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
