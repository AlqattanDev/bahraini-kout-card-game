import 'dart:ui';
import '../../theme/diwaniya_colors.dart';
import '../../theme/text_renderer.dart';

/// Utility for rendering bid action label + optional crown icon.
///
/// Shared by [PlayerSeatComponent] and [OpponentNameLabel].
class BidLabelPainter {
  /// Paints bid action label and optional crown on [canvas].
  ///
  /// Parameters:
  ///   - [canvas]: Canvas to draw on
  ///   - [bidAction]: Bid action string ('pass', bid value as string, or null)
  ///   - [center]: Center position of the label
  ///   - [offset]: Offset from center for label placement
  ///   - [showCrown]: Whether to show crown emoji when this player is the bidder
  ///   - [isBidder]: Whether this player is the bidder (needed if showCrown=true)
  static void paint(
    Canvas canvas, {
    String? bidAction,
    required Offset offset,
    bool showCrown = false,
    bool isBidder = false,
    Offset? crownOffset,
  }) {
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final color = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, color, offset, 9);

      if (showCrown && isBidder) {
        final crown = crownOffset ?? Offset(offset.dx - 25, offset.dy);
        TextRenderer.drawCentered(
          canvas,
          '\u{1F451}',
          DiwaniyaColors.goldAccent,
          crown,
          10,
        );
      }
    } else if (showCrown && isBidder) {
      // No bid action but is bidder — just show crown
      final crown = crownOffset ?? offset;
      TextRenderer.drawCentered(
        canvas,
        '\u{1F451}',
        DiwaniyaColors.goldAccent,
        crown,
        10,
      );
    }
  }
}
