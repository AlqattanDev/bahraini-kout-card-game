import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../../shared/models/enums.dart';
import '../theme/kout_theme.dart';

/// Displays a player seat: circular avatar frame, name, card count badge,
/// team color dot, gold rope border, and an active-turn glow pulse.
class PlayerSeatComponent extends PositionComponent {
  String playerName;
  int cardCount;
  bool isActive;
  bool isTeamA; // true = Team A, false = Team B
  bool isDealer;
  String? bidAction; // null = hasn't acted, "pass" = passed, "5"/"6"/"7"/"8" = bid amount
  String? bidLabel; // e.g. "Bid: 5 | ♠" — shown above the bidder's seat
  double timerProgress; // 0.0 = no timer, 0.0-1.0 = fraction of time remaining

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
    this.bidAction,
    this.timerProgress = 0.0,
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
    final fillPaint = Paint()..color = KoutTheme.secondary.withValues(alpha: 0.85);
    canvas.drawCircle(center, _radius - 2, fillPaint);

    // Outer ring — team color (full circle or timer arc)
    final teamColor = isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor;

    if (isActive && timerProgress > 0.0) {
      // Dim background ring
      final bgRingPaint = Paint()
        ..color = teamColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, _radius, bgRingPaint);

      // Timer arc — depletes clockwise from top
      final sweepAngle = timerProgress * math.pi * 2;
      final timerPaint = Paint()
        ..color = teamColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _radius),
        -math.pi / 2, // start from top
        sweepAngle,
        false,
        timerPaint,
      );
    } else {
      // Static full ring
      final ringPaint = Paint()
        ..color = teamColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, _radius, ringPaint);

      // Active border highlight (when no timer, e.g. waiting phase)
      if (isActive) {
        final activePaint = Paint()
          ..color = KoutTheme.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(center, _radius, activePaint);
      }
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

    // Team badge (bottom-right of circle)
    final badgeCenter = Offset(center.dx + _radius - 4, center.dy + _radius - 4);
    final badgePaint = Paint()..color = teamColor;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgePaint);
    final badgeBorderPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(badgeCenter, _badgeRadius, badgeBorderPaint);
    _drawText(
      canvas,
      isTeamA ? 'A' : 'B',
      const Color(0xFFFFFFFF),
      badgeCenter,
      10,
    );

    // Team color indicator dot (below avatar)
    final teamDotCenter = Offset(center.dx, center.dy + _radius + 8);
    final teamDotPaint = Paint()..color = teamColor;
    canvas.drawCircle(teamDotCenter, 5, teamDotPaint);
    // Thin border around team dot
    final teamDotBorder = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(teamDotCenter, 5, teamDotBorder);

    // Bid action label (shown during bidding)
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final labelColor = isPass
          ? const Color(0xFFCC4444)
          : KoutTheme.accent;
      _drawText(
        canvas,
        label,
        labelColor,
        Offset(center.dx, center.dy + _radius + 20),
        9,
      );
    }

    // Bid/trump info label (shown above bidder's seat during play)
    if (bidLabel != null) {
      _drawText(
        canvas,
        bidLabel!,
        KoutTheme.accent,
        Offset(center.dx, center.dy - _radius - 28),
        12,
      );
    }
  }

  /// Draws a gold rope border: two concentric dashed circles.
  void _drawRopeBorder(Canvas canvas, Offset center) {
    const dashCount = 24;
    const dashAngle = math.pi * 2 / dashCount;
    const dashLength = dashAngle * 0.55; // each dash covers ~55% of segment

    for (int ring = 0; ring < 2; ring++) {
      final r = _radius + 6.0 + ring * 3.5;
      final ropePaint = Paint()
        ..color = KoutTheme.accent.withValues(alpha: 0.6 - ring * 0.15)
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
    String? bidAction,
    String? bidLabel,
  }) {
    final wasActive = isActive;
    playerName = name;
    cardCount = cards;
    isActive = active;
    isTeamA = teamA;
    isDealer = dealer;
    this.bidAction = bidAction;
    this.bidLabel = bidLabel;
    // timerProgress is driven by KoutGame.update(), not state updates

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

  /// Briefly flashes gold to celebrate a trick win.
  void flashTrickWin() {
    add(_TrickWinFlashComponent(radius: _radius));
  }
}

/// Short-lived gold flash rendered around a seat when that player wins a trick.
///
/// Fades out over 0.4 seconds, then removes itself.
class _TrickWinFlashComponent extends Component {
  final double radius;
  double _life = 0.4;

  _TrickWinFlashComponent({required this.radius});

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Derive the center from the parent PlayerSeatComponent's size.
    final parent = this.parent;
    final Offset center;
    if (parent is PlayerSeatComponent) {
      center = Offset(parent.size.x / 2, parent.size.y / 2);
    } else {
      center = Offset.zero;
    }

    final alpha = (_life / 0.4 * 180).toInt().clamp(0, 180);
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = KoutTheme.accent.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

/// Animated glow ring that pulses behind an active player seat.
///
/// Uses a manual timer to pulse opacity between 0.20 and 0.65.
/// PositionComponent does not implement OpacityProvider, so we
/// drive the animation ourselves in [update].
class _GlowPulseComponent extends PositionComponent {
  final double radius;
  double _opacity = 0.4;
  double _elapsed = 0;

  static const double _minOpacity = 0.20;
  static const double _maxOpacity = 0.65;
  static const double _cycleDuration = 1.6; // full cycle seconds

  _GlowPulseComponent({required this.radius})
      : super(anchor: Anchor.center);

  @override
  void onMount() {
    super.onMount();
    final parentSeat = parent as PlayerSeatComponent;
    position = Vector2(
      parentSeat.size.x / 2,
      parentSeat.size.y / 2,
    );
    size = Vector2.all((radius + 12) * 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    // Triangle wave: 0→1→0 over _cycleDuration
    final t = (_elapsed % _cycleDuration) / _cycleDuration;
    final wave = t < 0.5 ? t * 2 : 2 - t * 2;
    _opacity = _minOpacity + (_maxOpacity - _minOpacity) * wave;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final glowPaint = Paint()
      ..color = Color.fromRGBO(
        KoutTheme.accent.red,
        KoutTheme.accent.green,
        KoutTheme.accent.blue,
        _opacity,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius + 8, glowPaint);
  }
}
