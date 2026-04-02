import 'dart:math' as math;
import 'dart:ui';
import 'diwaniya_colors.dart';

/// Procedural texture generators for the Diwaniya table theme.
class TextureGenerator {
  /// Creates a warm wood-grain radial gradient paint for the table background.
  /// Kept for backward compatibility.
  static Paint woodGrainPaint(Rect bounds) {
    return Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Color(0xFF3A4F4D),
          Color(0xFF2F403E),
          Color(0xFF1F2D2B),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds);
  }

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
          final highlightPaint = Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.02);
          canvas.drawRect(tileRect.deflate(2), highlightPaint);
        }
      }
    }
  }

  /// Draws a radial vignette darkening the edges of [bounds].
  static void drawVignette(Canvas canvas, Rect bounds) {
    final center = bounds.center;
    final radius = math.max(bounds.width, bounds.height) * 0.7;

    final vignetteShader = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0x00000000),
        const Color(0x00000000),
        DiwaniyaColors.vignette.withValues(alpha: 0.5),
        DiwaniyaColors.vignette.withValues(alpha: 0.8),
      ],
      stops: const [0.0, 0.5, 0.8, 1.0],
    ).createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    canvas.drawRect(bounds, Paint()..shader = vignetteShader);
  }
}
