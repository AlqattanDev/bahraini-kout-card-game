import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../../shared/models/card.dart';
import '../theme/card_painter.dart';
import '../theme/kout_theme.dart';

/// A Flame component that renders a single playing card.
///
/// Renders face-up or face-down. Supports tap callbacks with a lift effect
/// on touch-down / hover for highlighted (playable) cards.
class CardComponent extends PositionComponent with TapCallbacks, HoverCallbacks {
  GameCard? card;
  bool isFaceUp;
  bool isHighlighted;
  bool isDimmed;
  bool showShadow;
  final void Function(GameCard card)? onTap;

  /// The scale this card should return to after interactions (tap/hover).
  /// Defaults to 1.0 but is set higher (e.g. 1.4) for hand cards.
  final double restScale;

  bool _pressed = false;
  Vector2? _restPosition;

  CardComponent({
    this.card,
    this.isFaceUp = true,
    this.isHighlighted = false,
    this.isDimmed = false,
    this.showShadow = true,
    this.onTap,
    this.restScale = 1.0,
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

    // Drop shadow — drawn FIRST so it's behind the card
    if (showShadow) {
      final shadowRect = rrect.shift(
        const Offset(KoutTheme.cardShadowOffsetX, KoutTheme.cardShadowOffsetY),
      );
      final shadowPaint = Paint()
        ..color = KoutTheme.cardShadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, KoutTheme.cardShadowBlur);
      canvas.drawRRect(shadowRect, shadowPaint);
    }

    if (isFaceUp && card != null) {
      _renderFaceUp(canvas, rect, rrect);
    } else {
      CardPainter.paintBack(canvas, rect);
    }
  }

  void _renderFaceUp(Canvas canvas, Rect rect, RRect rrect) {
    final c = card!;

    if (c.isJoker) {
      CardPainter.paintJoker(canvas, rect);
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

    // Dim overlay for unplayable cards
    if (isDimmed) {
      final dimPaint = Paint()..color = const Color(0xAA000000);
      canvas.drawRRect(rrect, dimPaint);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isFaceUp || !isHighlighted) return;
    _pressed = true;
    _restPosition ??= position.clone();
    scale = Vector2.all(restScale * 1.1);
    position.y = (_restPosition?.y ?? position.y) - 8;
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_pressed) {
      _pressed = false;
      scale = Vector2.all(restScale);
      if (_restPosition != null) {
        position = _restPosition!.clone();
        _restPosition = null;
      }
      if (card != null && onTap != null) {
        onTap!(card!);
      }
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (_pressed) {
      _pressed = false;
      scale = Vector2.all(restScale);
      if (_restPosition != null) {
        position = _restPosition!.clone();
        _restPosition = null;
      }
    }
  }

  @override
  void onHoverEnter() {
    if (!isFaceUp || !isHighlighted) return;
    _restPosition ??= position.clone();
    scale = Vector2.all(restScale * 1.1);
    position.y = (_restPosition?.y ?? position.y) - 8;
  }

  @override
  void onHoverExit() {
    if (!_pressed) {
      scale = Vector2.all(restScale);
      if (_restPosition != null) {
        position = _restPosition!.clone();
        _restPosition = null;
      }
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
