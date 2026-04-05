import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/textures.dart';

/// Full-screen textured tile background with vignette.
class TableBackgroundComponent extends PositionComponent {
  bool isLandscape = false;

  TableBackgroundComponent() : super(position: Vector2.zero());

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    if (isLandscape) {
      // Clean radial green felt gradient for landscape
      final feltShader = Gradient.radial(
        rect.center,
        rect.longestSide * 0.6,
        [const Color(0xFF2d6b3a), const Color(0xFF1e4d2a), const Color(0xFF163d20)],
        [0.0, 0.5, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = feltShader);
      // Warm vignette
      TextureGenerator.drawVignette(canvas, rect);
    } else {
      TextureGenerator.drawTileTexture(canvas, rect);
      TextureGenerator.drawVignette(canvas, rect);
    }
  }
}
