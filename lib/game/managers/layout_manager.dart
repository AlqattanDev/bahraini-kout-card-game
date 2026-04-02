import 'dart:ui';
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

  /// Center of the partner seat (top) — below status bar with room for crown.
  Vector2 get partnerSeat => Vector2(width / 2, 120);

  /// Center of the left opponent seat.
  Vector2 get leftSeat => Vector2(80, height / 2);

  /// Center of the right opponent seat.
  Vector2 get rightSeat => Vector2(width - 80, height / 2);

  /// Center of the trick area.
  Vector2 get trickCenter => Vector2(width / 2, height / 2);

  /// Center of the trick tracker (8 circles between trick area and hand).
  Vector2 get trickTrackerCenter => Vector2(width / 2, trickCenter.y + 130);

  // ---------------------------------------------------------------------------
  // 3D Perspective table surface geometry
  // ---------------------------------------------------------------------------

  static const double _tableTopWidthRatio = 0.55;
  static const double _tableBottomWidthRatio = 0.85;

  double get _tableTopY => 70.0;
  double get _tableBottomY => height - 130.0;

  /// The 4 vertices of the perspective table trapezoid.
  /// Order: topLeft, topRight, bottomLeft, bottomRight.
  List<Offset> get tableVertices {
    final topHalf = width * _tableTopWidthRatio / 2;
    final botHalf = width * _tableBottomWidthRatio / 2;
    final cx = width / 2;
    return [
      Offset(cx - topHalf, _tableTopY),   // top-left
      Offset(cx + topHalf, _tableTopY),   // top-right
      Offset(cx - botHalf, _tableBottomY), // bottom-left
      Offset(cx + botHalf, _tableBottomY), // bottom-right
    ];
  }

  Offset get tableCenter {
    final v = tableVertices;
    return Offset(
      (v[0].dx + v[1].dx + v[2].dx + v[3].dx) / 4,
      (v[0].dy + v[1].dy + v[2].dy + v[3].dy) / 4,
    );
  }

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
  /// Spacing adapts: fewer cards = wider spacing, more cards = tighter.
  List<({Vector2 position, double angle})> handCardPositions(int cardCount) {
    if (cardCount == 0) return [];

    const maxFanAngle = 0.30;
    // Adaptive spacing: 70px for 4 cards, down to 48px for 8 cards
    final cardSpacing = (80 - cardCount * 4.0).clamp(44.0, 72.0);

    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = handCenter.x - totalWidth / 2;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      final arcOffset = (0.25 - t * t) * 32; // slightly more arc than before
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
