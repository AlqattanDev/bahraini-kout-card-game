import 'dart:math' as math;
import 'dart:ui';
import 'diwaniya_colors.dart';

/// Procedural texture generators for the Diwaniya table theme.
class TextureGenerator {
  /// Draws a repeating tile/brick texture pattern across [bounds].
  static void drawTileTexture(
    Canvas canvas,
    Rect bounds, {
    double tileW = 64.0,
    double tileH = 32.0,
  }) {
    final basePaint = Paint()..color = DiwaniyaColors.backgroundTile;
    canvas.drawRect(bounds, basePaint);

    final tilePaint = Paint()
      ..color = DiwaniyaColors.backgroundTileDark.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cols = (bounds.width / tileW).ceil() + 2;
    final rows = (bounds.height / tileH).ceil() + 2;

    for (int row = 0; row < rows; row++) {
      final offsetX = row.isOdd ? tileW / 2 : 0.0;
      for (int col = 0; col < cols; col++) {
        final x = bounds.left + col * tileW - offsetX;
        final y = bounds.top + row * tileH;
        final tileRect = Rect.fromLTWH(x, y, tileW, tileH);
        canvas.drawRect(tileRect, tilePaint);

        if ((row + col) % 3 == 0) {
          canvas.drawRect(tileRect.deflate(2), Paint()..color = DiwaniyaColors.tileHighlight);
        }
      }
    }
  }

  /// Draws a radial vignette darkening the edges of [bounds].
  static void drawVignette(Canvas canvas, Rect bounds, {double intensity = 0.5}) {
    final center = bounds.center;
    final radius = math.max(bounds.width, bounds.height) * 0.7;

    final vignetteShader = Gradient.radial(
      center,
      radius,
      [
        const Color(0x00000000),
        const Color(0x00000000),
        DiwaniyaColors.vignette.withValues(alpha: intensity * 0.8),
        DiwaniyaColors.vignette.withValues(alpha: intensity),
      ],
      [0.0, 0.5, 0.8, 1.0],
    );

    canvas.drawRect(bounds, Paint()..shader = vignetteShader);
  }
}
