import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/textures.dart';

/// Full-screen wood grain table background component.
///
/// Renders a warm dark-wood radial gradient filling the entire game canvas.
/// Should be added as the first child in [KoutGame] so it renders behind
/// all other components.
class TableBackgroundComponent extends PositionComponent {
  TableBackgroundComponent() : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, TextureGenerator.woodGrainPaint(rect));
  }
}
