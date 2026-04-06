import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/kout_theme.dart';
import 'painters/card_fan_painter.dart';

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

  /// Miniature card dimensions (50% of full card size — readable but secondary).
  static const double _miniWidth = KoutTheme.cardWidth * 0.50; // ~35
  static const double _miniHeight = KoutTheme.cardHeight * 0.50; // ~50

  /// Horizontal overlap between adjacent cards in the fan.
  static const double _fanOverlap = 10.0;

  /// Total angular spread of the fan (radians) — tighter for compact look.
  static const double _maxFanAngle = 0.40;

  /// Vertical arc bow amount — subtle curve, not dramatic.
  static const double _arcBow = 10.0;

  /// Scale factors to transform full-size card rect → mini card.
  static const double _scaleX = _miniWidth / KoutTheme.cardWidth;
  static const double _scaleY = _miniHeight / KoutTheme.cardHeight;

  /// Bounding box padding to accommodate rotated cards + arc.
  static const double _boundsPadding = 16.0;

  OpponentHandFan({
    required this.cardCount,
    required super.position,
    this.baseRotation = 0.0,
    super.anchor = Anchor.center,
  }) : super(
          size: Vector2(
            _miniWidth + _fanOverlap * 10 + _boundsPadding,
            _miniHeight + _arcBow + _boundsPadding,
          ),
        );

  void updateCardCount(int count) {
    cardCount = count;
  }

  @override
  void render(Canvas canvas) {
    if (cardCount <= 0) return;

    // Apply base rotation around the component center so the entire fan
    // points in the right direction (toward the table center).
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(baseRotation);

    CardFanPainter.paint(
      canvas,
      cardCount: cardCount,
      fanAngle: _maxFanAngle,
      arcBow: _arcBow,
      scaleX: _scaleX,
      scaleY: _scaleY,
      cardOverlap: _fanOverlap,
      miniWidth: _miniWidth,
      miniHeight: _miniHeight,
    );

    canvas.restore();
  }
}
