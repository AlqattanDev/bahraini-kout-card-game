import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import '../theme/kout_theme.dart';

/// Displays a player seat: circular avatar frame, name, card count badge,
/// team color dot, gold rope border, and an active-turn glow pulse.
class PlayerSeatComponent extends PositionComponent {
  String playerName;
  int cardCount;
  bool isActive;
  bool isTeamA; // true = Team A, false = Team B
  bool isDealer;

  static const double _radius = 36.0;
  static const double _badgeRadius = 12.0;

  // Glow pulse component — added/removed when active state changes
  _GlowPulseComponent? _glowPulse;

  PlayerSeatComponent({
    required this.playerName,
    required this.cardCount,
    required this.isActive,
    required this.isTeamA,
    this.isDealer = false,
    super.position,
    super.anchor = Anchor.center,
  }) : super(size: Vector2.all(_radius * 2 + 24));

  @override
  void onMount() {
    super.onMount();
    _updateGlowPulse();
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);

    // Gold rope border (concentric dashed circles)
    _drawRopeBorder(canvas, center);

    // Circle fill
    final fillPaint = Paint()..color = KoutTheme.secondary.withOpacity(0.85);
    canvas.drawCircle(center, _radius - 2, fillPaint);

    // Outer ring — team color
    final teamColor = isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor;
    final ringPaint = Paint()
      ..color = teamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, _radius, ringPaint);

    // Active border highlight
    if (isActive) {
      final activePaint = Paint()
        ..color = KoutTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, _radius, activePaint);
    }

    // Dealer dot
    if (isDealer) {
      final dealerPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawCircle(
        Offset(center.dx + _radius - 6, center.dy - _radius + 6),
        5,
        dealerPaint,
      );
    }

    // Player name
    _drawText(
      canvas,
      _truncateName(playerName),
      KoutTheme.textColor,
      Offset(center.dx, center.dy - 6),
      11,
    );

    // Card count badge (bottom-right of circle)
    final badgeCenter = Offset(center.dx + _radius - 4, center.dy + _radius - 4);
    final badgePaint = Paint()..color = KoutTheme.primary;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgePaint);
    final badgeBorderPaint = Paint()
      ..color = KoutTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgeBorderPaint);
    _drawText(
      canvas,
      '$cardCount',
      KoutTheme.textColor,
      badgeCenter,
      10,
    );

    // Team color indicator dot (below avatar)
    final teamDotCenter = Offset(center.dx, center.dy + _radius + 8);
    final teamDotPaint = Paint()..color = teamColor;
    canvas.drawCircle(teamDotCenter, 5, teamDotPaint);
    // Thin border around team dot
    final teamDotBorder = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(teamDotCenter, 5, teamDotBorder);
  }

  /// Draws a gold rope border: two concentric dashed circles.
  void _drawRopeBorder(Canvas canvas, Offset center) {
    const dashCount = 24;
    const dashAngle = math.pi * 2 / dashCount;
    const dashLength = dashAngle * 0.55; // each dash covers ~55% of segment

    for (int ring = 0; ring < 2; ring++) {
      final r = _radius + 6.0 + ring * 3.5;
      final ropePaint = Paint()
        ..color = KoutTheme.accent.withOpacity(0.6 - ring * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < dashCount; i++) {
        final startAngle = i * dashAngle + (ring.isOdd ? dashAngle / 2 : 0);
        final path = Path();
        path.addArc(
          Rect.fromCircle(center: center, radius: r),
          startAngle,
          dashLength,
        );
        canvas.drawPath(path, ropePaint);
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Color color,
    Offset center,
    double fontSize,
  ) {
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ParagraphConstraints(width: 80));

    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - 40, center.dy - fontSize / 2),
    );
  }

  String _truncateName(String name) {
    if (name.length <= 8) return name;
    return '${name.substring(0, 7)}…';
  }

  void updateState({
    required String name,
    required int cards,
    required bool active,
    required bool teamA,
    bool dealer = false,
  }) {
    final wasActive = isActive;
    playerName = name;
    cardCount = cards;
    isActive = active;
    isTeamA = teamA;
    isDealer = dealer;

    // Update glow pulse when active state changes
    if (wasActive != active && isMounted) {
      _updateGlowPulse();
    }
  }

  void _updateGlowPulse() {
    if (isActive) {
      if (_glowPulse == null) {
        _glowPulse = _GlowPulseComponent(radius: _radius);
        add(_glowPulse!);
      }
    } else {
      _glowPulse?.removeFromParent();
      _glowPulse = null;
    }
  }
}

/// Animated glow ring that pulses behind an active player seat.
class _GlowPulseComponent extends PositionComponent {
  final double radius;
  double _opacity = 0.4;

  _GlowPulseComponent({required this.radius})
      : super(anchor: Anchor.center);

  @override
  void onMount() {
    super.onMount();
    // Parent is PlayerSeatComponent; center within its coordinate space
    final parentSeat = parent as PlayerSeatComponent;
    position = Vector2(
      parentSeat.size.x / 2,
      parentSeat.size.y / 2,
    );
    size = Vector2.all((radius + 12) * 2);

    // Repeating opacity pulse: fade 0.15 → 0.5 → 0.15
    add(
      OpacityEffect.to(
        0.15,
        EffectController(
          duration: 0.8,
          reverseDuration: 0.8,
          infinite: true,
          curve: Curves.linear,
        ),
      ),
    );
    _opacity = 0.4;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final glowPaint = Paint()
      ..color = KoutTheme.accent.withOpacity(_opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 8, glowPaint);
  }
}
