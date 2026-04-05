import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

/// Calculates positions and angles for all game elements based on screen size.
/// Seat indices: 0=bottom (me), 1=left, 2=top (partner), 3=right.
class LayoutManager {
  final Vector2 screenSize;
  final EdgeInsets safeArea;

  LayoutManager(this.screenSize, {this.safeArea = EdgeInsets.zero});

  double get width => screenSize.x;
  double get height => screenSize.y;

  bool get isLandscape => width > height;

  /// The usable screen rect after subtracting safe area insets.
  Rect get safeRect => Rect.fromLTRB(
        safeArea.left,
        safeArea.top,
        width - safeArea.right,
        height - safeArea.bottom,
      );

  double get _safeWidth => safeRect.width;
  double get _safeHeight => safeRect.height;

  // ---------------------------------------------------------------------------
  // Dynamic card scale
  // ---------------------------------------------------------------------------

  /// Scale factor for hand cards. Smaller on landscape phones, 1.4x on portrait.
  double get handCardScale {
    if (!isLandscape) return 1.4;
    // Scale relative to safe height so cards are ~15% of available height
    return (safeRect.height * 0.15 / 100).clamp(0.6, 1.4);
  }

  // ---------------------------------------------------------------------------
  // Positions — delegates to portrait or landscape
  // ---------------------------------------------------------------------------

  Vector2 get handCenter => isLandscape ? _landscapeHandCenter : _portraitHandCenter;
  Vector2 get mySeat => isLandscape ? _landscapeMySeat : _portraitMySeat;
  Vector2 get partnerSeat => isLandscape ? _landscapePartnerSeat : _portraitPartnerSeat;
  Vector2 get leftSeat => isLandscape ? _landscapeLeftSeat : _portraitLeftSeat;
  Vector2 get rightSeat => isLandscape ? _landscapeRightSeat : _portraitRightSeat;
  Vector2 get trickCenter => isLandscape ? _landscapeTrickCenter : _portraitTrickCenter;
  Vector2 get trickTrackerCenter => Vector2(trickCenter.x, trickCenter.y + (isLandscape ? 80 : 130));

  // ---------------------------------------------------------------------------
  // Portrait positions (UNCHANGED from original)
  // ---------------------------------------------------------------------------

  Vector2 get _portraitHandCenter => Vector2(width / 2, height - 80);
  Vector2 get _portraitMySeat => Vector2(width - 60, height - 80);
  Vector2 get _portraitPartnerSeat => Vector2(width / 2, 120);
  Vector2 get _portraitLeftSeat => Vector2(80, height / 2);
  Vector2 get _portraitRightSeat => Vector2(width - 80, height / 2);
  Vector2 get _portraitTrickCenter => Vector2(width / 2, height / 2);

  // ---------------------------------------------------------------------------
  // Landscape positions (safe-area aware)
  // ---------------------------------------------------------------------------

  /// Hand at bottom-center of safe rect
  Vector2 get _landscapeHandCenter {
    final cardH = 100 * handCardScale;
    return Vector2(safeRect.center.dx, safeRect.bottom - cardH / 2 - 8);
  }

  /// Player label at bottom-right of safe rect
  Vector2 get _landscapeMySeat => Vector2(safeRect.right - 50, safeRect.bottom - 20);

  /// Partner label at top-center of safe rect
  Vector2 get _landscapePartnerSeat => Vector2(safeRect.center.dx, safeRect.top + 30);

  /// Left opponent at top-left of safe rect
  Vector2 get _landscapeLeftSeat => Vector2(safeRect.left + 60, safeRect.top + 30);

  /// Right opponent at top-right of safe rect
  Vector2 get _landscapeRightSeat => Vector2(safeRect.right - 60, safeRect.top + 30);

  /// Trick area slightly above center of safe rect
  Vector2 get _landscapeTrickCenter => Vector2(safeRect.center.dx, safeRect.top + _safeHeight * 0.48);

  // ---------------------------------------------------------------------------
  // 3D Perspective table surface geometry (portrait only)
  // ---------------------------------------------------------------------------

  static const double _tableTopWidthRatio = 0.55;
  static const double _tableBottomWidthRatio = 0.85;

  double get _tableTopY => 70.0;
  double get _tableBottomY => height - 130.0;

  List<Offset> get tableVertices {
    final topHalf = width * _tableTopWidthRatio / 2;
    final botHalf = width * _tableBottomWidthRatio / 2;
    final cx = width / 2;
    return [
      Offset(cx - topHalf, _tableTopY),
      Offset(cx + topHalf, _tableTopY),
      Offset(cx - botHalf, _tableBottomY),
      Offset(cx + botHalf, _tableBottomY),
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
  Vector2 trickCardPosition(int relativeSeat) {
    final offset = isLandscape ? 45.0 : 55.0;
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
  List<({Vector2 position, double angle})> handCardPositions(int cardCount) {
    if (cardCount == 0) return [];

    const maxFanAngle = 0.30;
    final cardSpacing = isLandscape
        ? (60 - cardCount * 3.0).clamp(32.0, 52.0)
        : (80 - cardCount * 4.0).clamp(44.0, 72.0);

    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = handCenter.x - totalWidth / 2;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      final arcBow = isLandscape ? 20.0 : 32.0;
      final arcOffset = (0.25 - t * t) * arcBow;
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

  int toRelativeSeat(int absoluteSeatIndex, int mySeatIndex) {
    return (absoluteSeatIndex - mySeatIndex + 4) % 4;
  }
}
