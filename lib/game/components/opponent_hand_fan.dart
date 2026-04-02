import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/card_painter.dart';
import '../theme/kout_theme.dart';

/// Renders miniature face-down card backs near an opponent seat,
/// visually indicating how many cards they hold.
///
/// Cards are drawn at 55% of full card size with the full card-back art
/// (geometric star pattern + gold inner border) scaled down via canvas
/// transform. The fan spreads in a natural arc with individually
/// distinguishable cards.
///
/// [baseRotation] controls the overall orientation of the fan:
///   - 0        → horizontal fan (cards spread left-to-right), used for top seat
///   - π/2      → vertical fan rotated clockwise (cards spread top-to-bottom),
///                 used for left seat (fan points toward center/right)
///   - -π/2     → vertical fan rotated counter-clockwise, used for right seat
///                 (fan points toward center/left)
class OpponentHandFan extends PositionComponent {
  int cardCount;

  /// Rotation applied to the entire fan (radians). Controls which direction
  /// the fan "points" from the player seat toward the table center.
  final double baseRotation;

  // ---------------------------------------------------------------------------
  // Layout constants
  // ---------------------------------------------------------------------------

  /// Miniature card dimensions (60% of full card size).
  static const double _miniWidth = KoutTheme.cardWidth * 0.60; // ~42
  static const double _miniHeight = KoutTheme.cardHeight * 0.60; // ~60

  /// Horizontal overlap between adjacent cards in the fan.
  static const double _cardOverlap = 14.0;

  /// Total angular spread of the fan (radians).
  static const double _maxFanAngle = 0.55;

  /// Vertical arc bow amount — higher = more curved fan.
  static const double _arcBow = 16.0;

  /// Scale factors to transform full-size card rect → mini card.
  static const double _scaleX = _miniWidth / KoutTheme.cardWidth;
  static const double _scaleY = _miniHeight / KoutTheme.cardHeight;

  /// Bounding box padding to accommodate rotated cards + arc.
  static const double _boundsPadding = 20.0;

  OpponentHandFan({
    required this.cardCount,
    required super.position,
    this.baseRotation = 0.0,
    super.anchor = Anchor.center,
  }) : super(
          size: Vector2(
            _miniWidth + _cardOverlap * 10 + _boundsPadding,
            _miniHeight + _arcBow + _boundsPadding,
          ),
        );

  void updateCardCount(int count) {
    cardCount = count;
  }

  @override
  void render(Canvas canvas) {
    if (cardCount <= 0) return;

    final displayCount = cardCount.clamp(1, 8);

    // Apply base rotation around the component center so the entire fan
    // points in the right direction (toward the table center).
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(baseRotation);

    for (int i = 0; i < displayCount; i++) {
      canvas.save();

      // t ranges from -0.5 to 0.5 across the fan
      final t = displayCount == 1
          ? 0.0
          : (i / (displayCount - 1)) - 0.5;
      final angle = t * _maxFanAngle;

      // Fan always spreads left-to-right in local space; baseRotation
      // handles the world orientation.
      final dx =
          i * _cardOverlap - (displayCount - 1) * _cardOverlap / 2;
      final dy = -(0.25 - t * t) * _arcBow; // center rises, edges drop

      canvas.translate(dx, dy);
      canvas.rotate(angle);

      // Draw shadow at mini scale
      final shadowRect = Rect.fromCenter(
        center: const Offset(1.5, 2.5),
        width: _miniWidth,
        height: _miniHeight,
      );
      final shadowRRect = RRect.fromRectAndRadius(
        shadowRect,
        Radius.circular(KoutTheme.cardBorderRadius * _scaleX),
      );
      canvas.drawRRect(
        shadowRRect,
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Scale down and delegate to CardPainter.paintBack() for full card-back
      // art (geometric star tessellation + gold inner border + white outer
      // border). This avoids duplicating the card-back design.
      canvas.save();
      canvas.translate(-_miniWidth / 2, -_miniHeight / 2);
      canvas.scale(_scaleX, _scaleY);
      final fullRect = Rect.fromLTWH(
        0,
        0,
        KoutTheme.cardWidth,
        KoutTheme.cardHeight,
      );
      CardPainter.paintBack(canvas, fullRect);
      canvas.restore();

      canvas.restore();
    }

    canvas.restore(); // undo baseRotation
  }
}
