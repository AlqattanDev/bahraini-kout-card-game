import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import '../../shared/models/card.dart';
import '../theme/card_painter.dart';
import '../theme/kout_theme.dart';

/// A Flame component that renders a single playing card.
///
/// Renders face-up or face-down. Supports tap callbacks with a lift effect
/// on touch-down / hover for highlighted (playable) cards.
class CardComponent extends PositionComponent with TapCallbacks, HoverCallbacks, HasPaint {
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
  bool _isLifted = false;

  ScaleEffect? _liftScaleEffect;
  MoveEffect? _liftMoveEffect;

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
    if (opacity < 1.0) {
      canvas.saveLayer(null, paint);
    }

    final rect = Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight);
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(KoutTheme.cardBorderRadius),
    );

    // Drop shadow — drawn FIRST so it's behind the card
    if (showShadow) {
      final double offsetY = _isLifted ? KoutTheme.cardShadowOffsetY + 2.0 : KoutTheme.cardShadowOffsetY;
      final double blur = _isLifted ? KoutTheme.cardShadowBlur + 4.0 : KoutTheme.cardShadowBlur;

      final shadowRect = rrect.shift(
        Offset(KoutTheme.cardShadowOffsetX, offsetY),
      );
      final shadowPaint = Paint()
        ..color = KoutTheme.cardShadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawRRect(shadowRect, shadowPaint);
    }

    if (isFaceUp && card != null) {
      _renderFaceUp(canvas, rect, rrect);
    } else {
      CardPainter.paintBack(canvas, rect);
    }

    if (opacity < 1.0) {
      canvas.restore();
    }
  }

  void _renderFaceUp(Canvas canvas, Rect rect, RRect rrect) {
    final c = card!;

    if (c.isJoker) {
      CardPainter.paintJoker(canvas, rect);
    } else {
      CardPainter.paintFace(
        canvas, rect, c.rank!.label, c.suit!.symbol, KoutTheme.suitCardColor(c.suit!),
      );
    }

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

  void _applyLift() {
    _restPosition ??= position.clone();
    _isLifted = true;

    _liftScaleEffect?.removeFromParent();
    _liftMoveEffect?.removeFromParent();

    _liftScaleEffect = ScaleEffect.to(
      Vector2.all(restScale * 1.1),
      EffectController(duration: 0.15, curve: Curves.easeOutCubic),
    );
    _liftMoveEffect = MoveEffect.to(
      _restPosition! + Vector2(0, -8),
      EffectController(duration: 0.15, curve: Curves.easeOutCubic),
    );

    add(_liftScaleEffect!);
    add(_liftMoveEffect!);
  }

  void _resetLift() {
    _isLifted = false;

    _liftScaleEffect?.removeFromParent();
    _liftMoveEffect?.removeFromParent();

    _liftScaleEffect = ScaleEffect.to(
      Vector2.all(restScale),
      EffectController(duration: 0.15, curve: Curves.easeOutCubic),
    );

    if (_restPosition != null) {
      _liftMoveEffect = MoveEffect.to(
        _restPosition!.clone(),
        EffectController(duration: 0.15, curve: Curves.easeOutCubic),
        onComplete: () {
          _restPosition = null;
        },
      );
      add(_liftMoveEffect!);
    }

    add(_liftScaleEffect!);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isFaceUp || !isHighlighted) return;
    HapticFeedback.selectionClick();
    _pressed = true;
    _applyLift();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_pressed) return;
    _pressed = false;
    _resetLift();
    if (card != null && onTap != null) onTap!(card!);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (!_pressed) return;
    _pressed = false;
    _resetLift();
  }

  @override
  void onHoverEnter() {
    if (!isFaceUp || !isHighlighted) return;
    _applyLift();
  }

  @override
  void onHoverExit() {
    if (!_pressed) _resetLift();
  }
}
