import 'dart:ui';
import '../../theme/card_painter.dart';
import '../../theme/kout_theme.dart';

/// Utility for rendering a fan of face-down card backs at arbitrary scale and rotation.
///
/// Shared by [OpponentHandFan] and [OpponentNameLabel].
class CardFanPainter {
  /// Paints a fan of face-down card backs on [canvas].
  ///
  /// Parameters:
  ///   - [canvas]: Canvas to draw on
  ///   - [cardCount]: Number of cards to display (clamped to 0-8)
  ///   - [fanAngle]: Total angular spread of the fan in radians (default 0.55)
  ///   - [arcBow]: Vertical arc curve amount (default 16.0)
  ///   - [scaleX]: Horizontal scale factor relative to full card width
  ///   - [scaleY]: Vertical scale factor relative to full card height
  ///   - [cardOverlap]: Horizontal overlap between adjacent cards (default 14.0)
  ///   - [miniWidth]: Card width after scaling (should equal cardWidth * scaleX)
  ///   - [miniHeight]: Card height after scaling (should equal cardHeight * scaleY)
  static void paint(
    Canvas canvas, {
    required int cardCount,
    double fanAngle = 0.55,
    double arcBow = 16.0,
    required double scaleX,
    required double scaleY,
    double cardOverlap = 14.0,
    required double miniWidth,
    required double miniHeight,
    bool drawShadow = true,
  }) {
    if (cardCount <= 0) return;

    final displayCount = cardCount.clamp(1, 8);

    for (int i = 0; i < displayCount; i++) {
      canvas.save();

      // t ranges from -0.5 to 0.5 across the fan
      final t = displayCount == 1 ? 0.0 : (i / (displayCount - 1)) - 0.5;
      final angle = t * fanAngle;

      // Fan spreads left-to-right in local space
      final dx = i * cardOverlap - (displayCount - 1) * cardOverlap / 2;
      final dy = -(0.25 - t * t) * arcBow; // center rises, edges drop

      canvas.translate(dx, dy);
      canvas.rotate(angle);

      // Draw shadow at mini scale
      if (drawShadow) {
        final shadowRect = Rect.fromCenter(
          center: const Offset(1.5, 2.5),
          width: miniWidth,
          height: miniHeight,
        );
        final shadowRRect = RRect.fromRectAndRadius(
          shadowRect,
          Radius.circular(KoutTheme.cardBorderRadius * scaleX),
        );
        canvas.drawRRect(
          shadowRRect,
          Paint()
            ..color = const Color(0x55000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      // Scale down and delegate to CardPainter.paintBack() for full card-back art
      canvas.save();
      canvas.translate(-miniWidth / 2, -miniHeight / 2);
      canvas.scale(scaleX, scaleY);
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
  }
}
