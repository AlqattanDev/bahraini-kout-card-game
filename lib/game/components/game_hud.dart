import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';

/// Compact top-left HUD showing round and trick counters.
class GameHudComponent extends PositionComponent {
  int roundNumber;
  int trickNumber;

  static const double _hudWidth = 90.0;
  static const double _hudHeight = 36.0;

  GameHudComponent({
    this.roundNumber = 1,
    this.trickNumber = 0,
    super.position,
    super.anchor = Anchor.topLeft,
  }) : super(
          size: Vector2(_hudWidth, _hudHeight),
        ) {
    position = Vector2(12, 14);
  }

  void updateRound(int round, {int trick = 0}) {
    roundNumber = round;
    trickNumber = trick;
  }

  @override
  void render(Canvas canvas) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, _hudHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, Paint()..color = DiwaniyaColors.scoreHudBg);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = DiwaniyaColors.scoreHudBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final text = 'R$roundNumber  T$trickNumber';
    TextRenderer.draw(
      canvas,
      text,
      DiwaniyaColors.cream.withValues(alpha: 0.8),
      Offset(_hudWidth / 2, (_hudHeight - 13) / 2),
      13,
      align: TextAlign.center,
      width: _hudWidth,
    );
  }
}
