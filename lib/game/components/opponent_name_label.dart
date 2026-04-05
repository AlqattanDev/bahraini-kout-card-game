import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
import '../theme/kout_theme.dart';
import '../theme/card_painter.dart';

/// Where the label sits on screen — determines anchor and internal layout.
enum OpponentLabelPlacement { top, left, right }

/// Lightweight landscape-mode label for an opponent: name, team dot,
/// bid status, and a small face-down card fan.
class OpponentNameLabel extends PositionComponent {
  String playerName;
  bool isTeamA;
  String? bidAction;
  bool isBidder;
  bool isActive;
  int cardCount;
  OpponentLabelPlacement placement;

  static const double _miniCardW = 22.0;
  static const double _miniCardH = 31.0;
  static const double _cardOverlap = 10.0;
  static const int _fanDisplayCount = 5;
  static const double _scaleX = _miniCardW / KoutTheme.cardWidth;
  static const double _scaleY = _miniCardH / KoutTheme.cardHeight;

  OpponentNameLabel({
    required this.playerName,
    required this.isTeamA,
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
      OpponentLabelPlacement.top => Vector2(140, 60),
      OpponentLabelPlacement.left || OpponentLabelPlacement.right => Vector2(80, 90),
    };
  }

  static Anchor _anchorForPlacement(OpponentLabelPlacement p) {
    return switch (p) {
      OpponentLabelPlacement.top => Anchor.topCenter,
      OpponentLabelPlacement.left => Anchor.center,
      OpponentLabelPlacement.right => Anchor.center,
    };
  }

  void updateState({
    required String name,
    required bool teamA,
    required bool active,
    required int cards,
    String? bidAction,
    bool isBidder = false,
  }) {
    playerName = name;
    isTeamA = teamA;
    isActive = active;
    cardCount = cards;
    this.bidAction = bidAction;
    this.isBidder = isBidder;
  }

  @override
  void render(Canvas canvas) {
    if (placement == OpponentLabelPlacement.top) {
      _renderTop(canvas);
    } else {
      _renderSide(canvas);
    }
  }

  /// Top placement: name row on top, card fan below (for partner at top-center).
  void _renderTop(Canvas canvas) {
    final cx = size.x / 2;

    // Team dot
    final dotPaint = Paint()..color = (isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor);
    canvas.drawCircle(Offset(cx - 45, 8), 3, dotPaint);

    // Active glow
    if (isActive) {
      final glowPaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 8), width: 100, height: 18),
          const Radius.circular(9),
        ),
        glowPaint,
      );
    }

    // Name
    TextRenderer.drawCentered(
      canvas, playerName,
      isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream,
      Offset(cx - 10, 8), 9,
    );

    // Crown
    if (isBidder) {
      TextRenderer.drawCentered(canvas, '\u{1F451}', DiwaniyaColors.goldAccent, Offset(cx + 30, 8), 8);
    }

    // Bid action
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final color = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, color, Offset(cx + 50, 8), 7);
    }

    // Card fan
    _renderFan(canvas, cx, 22.0);
  }

  /// Side placement: name on top, card fan below, compact vertical stack.
  void _renderSide(Canvas canvas) {
    final cx = size.x / 2;

    // Team dot
    final dotPaint = Paint()..color = (isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor);
    canvas.drawCircle(Offset(cx - 25, 8), 3, dotPaint);

    // Active glow
    if (isActive) {
      final glowPaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 8), width: 70, height: 16),
          const Radius.circular(8),
        ),
        glowPaint,
      );
    }

    // Name (compact)
    TextRenderer.drawCentered(
      canvas, playerName,
      isActive ? DiwaniyaColors.goldAccent : DiwaniyaColors.cream,
      Offset(cx, 8), 8,
    );

    // Bid action (below name)
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final color = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, color, Offset(cx, 22), 7);
    } else if (isBidder) {
      TextRenderer.drawCentered(canvas, '\u{1F451}', DiwaniyaColors.goldAccent, Offset(cx, 22), 8);
    }

    // Card fan (below text)
    _renderFan(canvas, cx, 36.0);
  }

  void _renderFan(Canvas canvas, double centerX, double fanY) {
    final displayCount = cardCount.clamp(0, 8);
    if (displayCount == 0) return;

    final totalFanWidth = _miniCardW + (_fanDisplayCount - 1) * _cardOverlap;
    final fanStartX = centerX - totalFanWidth / 2;

    for (int i = 0; i < displayCount && i < _fanDisplayCount; i++) {
      final t = _fanDisplayCount == 1 ? 0.0 : (i / (_fanDisplayCount - 1)) - 0.5;
      final angle = t * 0.40;
      final dx = fanStartX + i * _cardOverlap;
      final dy = fanY - (0.25 - t * t) * 8;

      canvas.save();
      canvas.translate(dx + _miniCardW / 2, dy + _miniCardH / 2);
      canvas.rotate(angle);
      canvas.translate(-_miniCardW / 2, -_miniCardH / 2);
      canvas.scale(_scaleX, _scaleY);
      CardPainter.paintBack(
        canvas,
        Rect.fromLTWH(0, 0, KoutTheme.cardWidth, KoutTheme.cardHeight),
      );
      canvas.restore();
    }
  }
}
