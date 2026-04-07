import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import '../theme/kout_theme.dart';

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

  // Landscape zone budget (proportional to safeRect)
  static const double _handBleedRatio = 0.05;      // 5% of card hidden below edge — rank+suit always visible

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
    // Target 35% of safe height relative to actual card base height (70px).
    return (safeRect.height * 0.35 / KoutTheme.cardHeight).clamp(1.0, 1.6);
  }

  /// Trick cards noticeably smaller than hand cards so 4 cards don't overwhelm
  /// the table. ~65% of hand scale in landscape, 0.85x in portrait.
  double get trickCardScale {
    if (!isLandscape) return handCardScale * 0.85;
    return (handCardScale * 0.60).clamp(0.8, 1.1);
  }

  /// Proportional trick card offset (11% of shorter safe dimension).
  double get trickOffset {
    final base = safeRect.width < safeRect.height
        ? safeRect.width
        : safeRect.height;
    return base * 0.11;
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
  /// 20% of scaled card height hidden below edge.
  Vector2 get _landscapeHandCenter {
    final bleedAmount = KoutTheme.cardHeight * handCardScale * _handBleedRatio;
    return Vector2(safeRect.center.dx, height + bleedAmount);
  }

  /// Partner: top-center, with gap above table
  Vector2 get _landscapePartnerSeat => Vector2(
        safeRect.center.dx,
        safeRect.top + safeRect.height * 0.14,
      );

  /// Left opponent: near left edge, lowered into bottom half of table
  Vector2 get _landscapeLeftSeat => Vector2(
        safeRect.left + safeRect.width * 0.10,
        safeRect.top + safeRect.height * 0.64,
      );

  /// Right opponent: near right edge, lowered into bottom half of table
  Vector2 get _landscapeRightSeat => Vector2(
        safeRect.right - safeRect.width * 0.10,
        safeRect.top + safeRect.height * 0.64,
      );

  /// Human player: bottom-right, near the hand cards
  Vector2 get _landscapeMySeat => Vector2(
        safeRect.right - safeRect.width * 0.12,
        safeRect.bottom - safeRect.height * 0.12,
      );

  /// Trick area: centroid of the table surface
  Vector2 get _landscapeTrickCenter {
    final tc = tableCenter;
    return Vector2(tc.dx, tc.dy);
  }

  // ---------------------------------------------------------------------------
  // 3D Perspective table surface geometry (portrait only)
  // ---------------------------------------------------------------------------

  static const double _tableTopWidthRatio = 0.55;
  static const double _tableBottomWidthRatio = 0.85;

  double get _tableTopY => 70.0;
  double get _tableBottomY => height - _portraitTrickTrackerYOffset;

  List<Offset> get tableVertices =>
      isLandscape ? _landscapeTableVertices : _portraitTableVertices;

  List<Offset> get _portraitTableVertices {
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

  List<Offset> get _landscapeTableVertices {
    final playTop = safeRect.top + safeRect.height * 0.26;
    final playBot = safeRect.bottom - safeRect.height * 0.18;
    final cx = safeRect.center.dx;
    final topHalf = safeRect.width * 0.24;
    final botHalf = safeRect.width * 0.35;
    return [
      Offset(cx - topHalf, playTop),
      Offset(cx + topHalf, playTop),
      Offset(cx - botHalf, playBot),
      Offset(cx + botHalf, playBot),
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
        : (85 - cardCount * 4.0).clamp(48.0, 76.0);

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
