import 'dart:math';
import 'package:flame/components.dart';

/// Calculates positions and angles for all game elements based on screen size.
/// Seat indices: 0=bottom (me), 1=left, 2=top (partner), 3=right.
class LayoutManager {
  final Vector2 screenSize;

  LayoutManager(this.screenSize);

  double get width => screenSize.x;
  double get height => screenSize.y;

  /// Center of the player's hand at the bottom of the screen.
  Vector2 get handCenter => Vector2(width / 2, height - 80);

  /// Position for the human player's avatar (bottom-right, beside the hand).
  Vector2 get mySeat => Vector2(width - 60, height - 80);

  /// Center of the partner seat (top) — just under the 52px banner.
  Vector2 get partnerSeat => Vector2(width / 2, 100);

  /// Center of the left opponent seat.
  Vector2 get leftSeat => Vector2(80, height / 2);

  /// Center of the right opponent seat.
  Vector2 get rightSeat => Vector2(width - 80, height / 2);

  /// Center of the trick area.
  Vector2 get trickCenter => Vector2(width / 2, height / 2);

  /// Center of the trick tracker (8 circles between trick area and hand).
  Vector2 get trickTrackerCenter => Vector2(width / 2, trickCenter.y + 130);

  /// Position for a trick card played by relative seat index.
  /// relativeSeat: 0=bottom, 1=left, 2=top, 3=right
  Vector2 trickCardPosition(int relativeSeat) {
    const offset = 55.0;
    switch (relativeSeat) {
      case 0:
        return trickCenter + Vector2(0, offset);
      case 1:
        return trickCenter + Vector2(-offset, 0);
      case 2:
        return trickCenter + Vector2(0, -offset);
      case 3:
        return trickCenter + Vector2(offset, 0);
      default:
        return trickCenter;
    }
  }

  /// Returns card positions for fanning [cardCount] cards in the player's hand.
  /// Returns list of (position, angle) tuples.
  List<({Vector2 position, double angle})> handCardPositions(int cardCount) {
    if (cardCount == 0) return [];

    const maxFanAngle = 0.30; // radians total spread (slightly tighter for scaled cards)
    const cardSpacing = 56.0; // wider spacing to accommodate 1.4x scaled cards

    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = handCenter.x - totalWidth / 2;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      // Arc: center cards rise, edge cards drop — natural hand-held fan shape.
      // (0.25 - t²) is max at center (t=0) and zero at edges (t=±0.5).
      final arcOffset = (0.25 - t * t) * 28;
      final pos = Vector2(startX + i * cardSpacing, handCenter.y - arcOffset);
      results.add((position: pos, angle: angle));
    }

    return results;
  }

  /// Returns the screen position for a given absolute seat index based on myIndex.
  Vector2 seatPosition(int absoluteSeatIndex, int mySeatIndex) {
    final relative = (absoluteSeatIndex - mySeatIndex + 4) % 4;
    switch (relative) {
      case 0:
        return mySeat;
      case 1:
        return leftSeat;
      case 2:
        return partnerSeat;
      case 3:
        return rightSeat;
      default:
        return trickCenter;
    }
  }

  /// Converts an absolute seat index to relative seat index from perspective of mySeatIndex.
  int toRelativeSeat(int absoluteSeatIndex, int mySeatIndex) {
    return (absoluteSeatIndex - mySeatIndex + 4) % 4;
  }
}
