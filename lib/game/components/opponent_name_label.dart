import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
import '../theme/kout_theme.dart';
import 'painters/bid_label_painter.dart';
import 'painters/card_fan_painter.dart';

/// Where the label sits on screen — determines anchor and internal layout.
enum OpponentLabelPlacement { top, left, right }

/// Lightweight landscape-mode label for an opponent: name, team dot,
/// bid status, and a small face-down card fan.
class OpponentNameLabel extends PositionComponent {
  final int seatIndex;
  String playerName;
  Team team;
  String? bidAction;
  bool isBidder;
  bool isActive;
  int cardCount;
  OpponentLabelPlacement placement;

  static const double _miniCardW = 38.0;
  static const double _miniCardH = 54.0;
  static const double _cardOverlap = 18.0;
  static const int _fanDisplayCount = 5;
  static const double _scaleX = _miniCardW / KoutTheme.cardWidth;
  static const double _scaleY = _miniCardH / KoutTheme.cardHeight;

  OpponentNameLabel({
    required this.seatIndex,
    required this.playerName,
    required this.team,
    this.bidAction,
    this.isBidder = false,
    this.isActive = false,
    this.cardCount = 8,
    this.placement = OpponentLabelPlacement.top,
    super.position,
  }) : super(
          size: _sizeForPlacement(placement),
          anchor: _anchorForPlacement(placement),
        );

  static Vector2 _sizeForPlacement(OpponentLabelPlacement p) {
    return switch (p) {
      OpponentLabelPlacement.top => Vector2(180, 90),
      OpponentLabelPlacement.left || OpponentLabelPlacement.right => Vector2(130, 130),
    };
  }

  static Anchor _anchorForPlacement(OpponentLabelPlacement p) {
    return switch (p) {
      OpponentLabelPlacement.top => Anchor.topCenter,
      OpponentLabelPlacement.left => Anchor.center,
      OpponentLabelPlacement.right => Anchor.center,
    };
  }

  void updateState(ClientGameState state) {
    final uid = state.playerUids[seatIndex];
    playerName = shortUid(uid);
    team = teamForSeat(seatIndex);
    isActive = state.currentPlayerUid == uid;
    cardCount = state.cardCounts[seatIndex] ?? 8;

    // Bid status
    final showBid = state.phase == GamePhase.bidding ||
        state.phase == GamePhase.trumpSelection;
    if (showBid) {
      String? action;
      for (final entry in state.bidHistory) {
        if (entry.playerUid == uid) action = entry.action;
      }
      bidAction = action;
    } else {
      bidAction = null;
    }

    // Bidder glow (shown outside bidding/waiting/dealing)
    final showBidder = state.phase != GamePhase.bidding &&
        state.phase != GamePhase.waiting &&
        state.phase != GamePhase.dealing;
    isBidder = showBidder && uid == state.bidderUid;
  }

  @override
  void render(Canvas canvas) {
    final isTop = placement == OpponentLabelPlacement.top;
    final cx = size.x / 2;

    canvas.drawCircle(
      Offset(cx - (isTop ? 55 : 35), 10), 4,
      Paint()..color = KoutTheme.teamColor(team),
    );

    if (isActive) {
      final glowPaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isTop ? 6 : 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, 10),
            width: isTop ? 120 : 90,
            height: isTop ? 20 : 18,
          ),
          Radius.circular(isTop ? 10 : 9),
        ),
        glowPaint,
      );
    }

    final nameColor = isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream;
    TextRenderer.drawCentered(
      canvas, playerName, nameColor,
      Offset(isTop ? cx - 10 : cx, 10), isTop ? 11.0 : 10.0,
    );

    // Bid action label + bidder crown — position differs by placement
    _drawBidStatus(canvas, cx, isTop);

    _renderFan(canvas, cx, isTop ? 26.0 : 40.0);
  }

  void _drawBidStatus(Canvas canvas, double cx, bool isTop) {
    final labelOffset = isTop ? Offset(cx + 60, 10) : Offset(cx, 26);
    final crown = isTop ? Offset(cx + 40, 10) : Offset(cx, 26);
    BidLabelPainter.paint(
      canvas,
      bidAction: bidAction,
      offset: labelOffset,
      showCrown: true,
      isBidder: isBidder,
      crownOffset: crown,
    );
  }

  static const double _fanAngle = 0.40;
  static const double _fanArcBow = 8.0;

  void _renderFan(Canvas canvas, double centerX, double fanY) {
    final displayCount = cardCount.clamp(0, _fanDisplayCount);
    if (displayCount == 0) return;

    canvas.save();
    canvas.translate(centerX, fanY + _miniCardH / 2);
    CardFanPainter.paint(
      canvas,
      cardCount: displayCount,
      fanAngle: _fanAngle,
      arcBow: _fanArcBow,
      scaleX: _scaleX,
      scaleY: _scaleY,
      cardOverlap: _cardOverlap,
      miniWidth: _miniCardW,
      miniHeight: _miniCardH,
      drawShadow: false,
    );
    canvas.restore();
  }
}
