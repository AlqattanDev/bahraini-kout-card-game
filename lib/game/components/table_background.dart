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
    TextureGenerator.drawTileTexture(canvas, rect);
    TextureGenerator.drawVignette(canvas, rect,
        intensity: isLandscape ? 0.35 : 0.5);
  }
}
