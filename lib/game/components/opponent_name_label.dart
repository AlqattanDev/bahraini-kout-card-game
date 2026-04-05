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
  double _glowElapsed = 0.0;
  static const double _glowCycleDuration = 1.6;
  static const double _glowMinAlpha = 0.15;
  static const double _glowMaxAlpha = 0.50;
  OpponentLabelPlacement placement;

  static const double _miniCardW = 42.0;   // 55% of 70 ≈ 42
  static const double _miniCardH = 60.0;   // 55% of 100 = 60
  static const double _cardOverlap = 14.0; // tighter overlap
  static const int _fanDisplayCount = 8;   // show all cards
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
      OpponentLabelPlacement.top => Vector2(200, 100),
      OpponentLabelPlacement.left || OpponentLabelPlacement.right => Vector2(140, 150),
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
    final wasActive = isActive;
    playerName = shortUid(uid);
    team = teamForSeat(seatIndex);
    isActive = state.currentPlayerUid == uid;
    cardCount = state.cardCounts[seatIndex] ?? 8;
    if (isActive && !wasActive) _glowElapsed = 0.0;

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
  void update(double dt) {
    super.update(dt);
    if (isActive) {
      _glowElapsed += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final isTop = placement == OpponentLabelPlacement.top;
    final cx = size.x / 2;

    // --- Active player glow (prominent, team-colored) ---
    if (isActive) {
      final teamColor = KoutTheme.teamColor(team);
      final t = (_glowElapsed % _glowCycleDuration) / _glowCycleDuration;
      final wave = t < 0.5 ? t * 2 : 2 - t * 2;
      final alpha = _glowMinAlpha + (_glowMaxAlpha - _glowMinAlpha) * wave;

      final glowPaint = Paint()
        ..color = teamColor.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isTop ? 12 : 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, isTop ? 12 : 10),
            width: isTop ? 150 : 110,
            height: isTop ? 28 : 24,
          ),
          Radius.circular(isTop ? 14 : 12),
        ),
        glowPaint,
      );
    }

    // --- Team indicator: colored dot + team letter ---
    final teamColor = KoutTheme.teamColor(team);
    final dotX = cx - (isTop ? 60 : 40);
    canvas.drawCircle(Offset(dotX, isTop ? 12 : 10), 4, Paint()..color = teamColor);
    final teamLetter = team == Team.a ? 'A' : 'B';
    TextRenderer.draw(canvas, teamLetter, teamColor.withValues(alpha: 0.8),
        Offset(dotX + 8, isTop ? 6 : 4), 8, align: TextAlign.left, width: 12);

    // --- Player name ---
    final nameColor = isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream;
    TextRenderer.drawCentered(
      canvas, playerName, nameColor,
      Offset(isTop ? cx : cx, isTop ? 12 : 10), isTop ? 11.0 : 10.0,
    );

    // Bid action label + bidder crown
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
