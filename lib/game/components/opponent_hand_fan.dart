import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/kout_theme.dart';

/// Direction the fan spreads from the player seat.
enum FanDirection { left, right, above }

/// Renders miniature face-down card backs near an opponent seat,
/// visually indicating how many cards they hold.
class OpponentHandFan extends PositionComponent {
  int cardCount;
  final FanDirection fanDirection;

  /// Miniature card dimensions (38% of full card size).
  static const double _miniWidth = KoutTheme.cardWidth * 0.38;
  static const double _miniHeight = KoutTheme.cardHeight * 0.38;
  static const double _cardOverlap = 8.0;
  static const double _maxFanAngle = 0.25;

  OpponentHandFan({
    required this.cardCount,
    required super.position,
    required this.fanDirection,
    super.anchor = Anchor.center,
  }) : super(size: Vector2(_miniWidth + _cardOverlap * 8, _miniHeight + 20));

  void updateCardCount(int count) {
    cardCount = count;
  }

  @override
  void render(Canvas canvas) {
    if (cardCount <= 0) return;

    final displayCount = cardCount.clamp(1, 8);

    for (int i = 0; i < displayCount; i++) {
      canvas.save();

      final t = displayCount == 1
          ? 0.0
          : (i / (displayCount - 1)) - 0.5;
      final angle = t * _maxFanAngle;

      double dx, dy;
      switch (fanDirection) {
        case FanDirection.right:
          dx = i * _cardOverlap;
          dy = (t * t) * 6;
        case FanDirection.left:
          dx = -i * _cardOverlap;
          dy = (t * t) * 6;
        case FanDirection.above:
          dx = i * _cardOverlap - (displayCount - 1) * _cardOverlap / 2;
          dy = -(t * t) * 6;
      }

      canvas.translate(size.x / 2 + dx, size.y / 2 + dy);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: _miniWidth,
        height: _miniHeight,
      );

      // Mini shadow
      final shadowRect = rect.shift(const Offset(1, 1.5));
      final shadowRRect = RRect.fromRectAndRadius(
        shadowRect,
        Radius.circular(KoutTheme.cardBorderRadius * 0.4),
      );
      canvas.drawRRect(
        shadowRRect,
        Paint()
          ..color = const Color(0x44000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Mini card back
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(KoutTheme.cardBorderRadius * 0.4),
      );
      canvas.drawRRect(rrect, Paint()..color = KoutTheme.cardBack);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Simple gold diamond ornament in center
      final diamondSize = _miniWidth * 0.25;
      final diamondPath = Path()
        ..moveTo(0, -diamondSize)
        ..lineTo(diamondSize * 0.6, 0)
        ..lineTo(0, diamondSize)
        ..lineTo(-diamondSize * 0.6, 0)
        ..close();
      canvas.drawPath(
        diamondPath,
        Paint()..color = KoutTheme.accent.withOpacity(0.5),
      );

      canvas.restore();
    }
  }
}
