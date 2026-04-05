import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

/// Calculates positions and angles for all game elements based on screen size.
/// Seat indices: 0=bottom (me), 1=left, 2=top (partner), 3=right.
class LayoutManager {
  final Vector2 screenSize;
  final EdgeInsets safeArea;

  // Named constants for portrait layout values
  static const double _portraitHandBottomOffset = 80.0;
  static const double _portraitPartnerTopOffset = 120.0;
  static const double _portraitSeatEdgeInset = 80.0;
  static const double _portraitTrickOffset = 55.0;
  static const double _portraitArcBow = 32.0;
  static const double _portraitTrickTrackerYOffset = 130.0;

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

  // ---------------------------------------------------------------------------
  // Dynamic card scale
  // ---------------------------------------------------------------------------

  /// Scale factor for hand cards. Smaller on landscape phones, 1.4x on portrait.
  double get handCardScale {
    if (!isLandscape) return 1.4;
    // Cards are ~100px tall at scale 1.0. Target 33% of safe height:
    // (safeHeight * 0.33) / cardBaseHeight → scale factor.
    return (safeRect.height * 0.33 / 100).clamp(1.0, 1.6);
  }

  /// Scale for trick-area cards — matches hand cards for visual consistency.
  /// Hierarchy comes from position/rotation, not size difference.
  double get trickCardScale {
    if (!isLandscape) return 1.0;
    return handCardScale;
  }

  /// Proportional trick card offset (12% of shorter safe dimension).
  double get trickOffset {
    final base = safeRect.width < safeRect.height
        ? safeRect.width
        : safeRect.height;
    return base * 0.12;
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
  Vector2 get trickTrackerCenter => Vector2(
        trickCenter.x,
        trickCenter.y + (isLandscape ? safeRect.height * 0.16 : _portraitTrickTrackerYOffset),
      );

  // ---------------------------------------------------------------------------
  // Portrait positions (UNCHANGED from original)
  // ---------------------------------------------------------------------------

  Vector2 get _portraitHandCenter => Vector2(width / 2, height - _portraitHandBottomOffset);
  Vector2 get _portraitMySeat => Vector2(width - 60, height - _portraitHandBottomOffset);
  Vector2 get _portraitPartnerSeat => Vector2(width / 2, _portraitPartnerTopOffset);
  Vector2 get _portraitLeftSeat => Vector2(_portraitSeatEdgeInset, height / 2);
  Vector2 get _portraitRightSeat => Vector2(width - _portraitSeatEdgeInset, height / 2);
  Vector2 get _portraitTrickCenter => Vector2(width / 2, height / 2);

  // ---------------------------------------------------------------------------
  // Landscape positions (safe-area aware, opponents on sides)
  // ---------------------------------------------------------------------------

  /// Hand at bottom-center, pushed below screen edge so cards bleed off-screen.
  /// 15% of scaled card height hidden below edge.
  Vector2 get _landscapeHandCenter {
    final bleedAmount = 100 * handCardScale * 0.15;
    return Vector2(safeRect.center.dx, height + bleedAmount);
  }

  /// Player label at bottom-right, near the hand
  Vector2 get _landscapeMySeat => Vector2(
        safeRect.right - safeRect.width * 0.10,
        safeRect.bottom - safeRect.height * 0.08,
      );

  /// Partner label at top-center of safe rect
  Vector2 get _landscapePartnerSeat => Vector2(
        safeRect.center.dx,
        safeRect.top + safeRect.height * 0.08,
      );

  /// Left opponent at left side, vertically centered in safe rect
  Vector2 get _landscapeLeftSeat => Vector2(
        safeRect.left + safeRect.width * 0.12,
        safeRect.center.dy,
      );

  /// Right opponent at right side, vertically centered in safe rect
  Vector2 get _landscapeRightSeat => Vector2(
        safeRect.right - safeRect.width * 0.12,
        safeRect.center.dy,
      );

  /// Trick area at center of safe rect, slightly above center
  Vector2 get _landscapeTrickCenter => Vector2(
        safeRect.center.dx,
        safeRect.center.dy - safeRect.height * 0.04,
      );

  // ---------------------------------------------------------------------------
  // 3D Perspective table surface geometry (portrait only)
  // ---------------------------------------------------------------------------

  static const double _tableTopWidthRatio = 0.55;
  static const double _tableBottomWidthRatio = 0.85;

  double get _tableTopY => 70.0;
  double get _tableBottomY => height - _portraitTrickTrackerYOffset;

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
    final offset = isLandscape ? trickOffset : _portraitTrickOffset;
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

    const maxFanAngle = 0.55;
    final cardSpacing = isLandscape
        ? (safeRect.width * 0.055 - cardCount * 2.0).clamp(
            safeRect.width * 0.03,
            safeRect.width * 0.06,
          )
        : (80 - cardCount * 4.0).clamp(44.0, 72.0);

    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = handCenter.x - totalWidth / 2;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      final arcBow = isLandscape ? safeRect.height * 0.06 : _portraitArcBow;
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
