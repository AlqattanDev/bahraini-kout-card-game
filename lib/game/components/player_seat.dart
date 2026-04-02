import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../theme/kout_theme.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
import 'avatar_painter.dart';

/// Displays a player seat: avatar, name pill, gold rope border,
/// and an active-turn bright green ring.
class PlayerSeatComponent extends PositionComponent {
  String playerName;
  int cardCount;
  bool isActive;
  bool isTeamA;
  bool isDealer;
  final int avatarSeed;
  String? bidAction;
  bool isBidder = false;
  Color? bidderGlowColor;
  double timerProgress;

  static const double _radius = 36.0;

  _GlowPulseComponent? _glowPulse;

  PlayerSeatComponent({
    required this.playerName,
    required this.cardCount,
    required this.isActive,
    required this.isTeamA,
    this.avatarSeed = 0,
    this.isDealer = false,
    this.bidAction,
    this.timerProgress = 0.0,
    super.position,
    super.anchor = Anchor.center,
  }) : super(size: Vector2(_radius * 2 + 24, _radius * 2 + 48));

  @override
  void onMount() {
    super.onMount();
    _updateGlowPulse();
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2 - 10);

    // Gold rope border
    _drawRopeBorder(canvas, center);

    // Bidder glow ring — static, behind everything else
    if (isBidder && bidderGlowColor != null) {
      final glowPaint = Paint()
        ..color = bidderGlowColor!.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, _radius + 6, glowPaint);
    }

    // Character avatar
    AvatarPainter.paint(canvas, center, _radius - 3, AvatarTraits.fromSeed(avatarSeed));

    // Active turn ring — bright green, 5px
    if (isActive) {
      if (timerProgress > 0.0) {
        // Dim background ring
        final bgRingPaint = Paint()
          ..color = DiwaniyaColors.activeTurnRing.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        canvas.drawCircle(center, _radius, bgRingPaint);

        // Timer arc
        final sweepAngle = timerProgress * math.pi * 2;
        final timerPaint = Paint()
          ..color = DiwaniyaColors.activeTurnRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _radius),
          -math.pi / 2,
          sweepAngle,
          false,
          timerPaint,
        );
      } else {
        final activePaint = Paint()
          ..color = DiwaniyaColors.activeTurnRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        canvas.drawCircle(center, _radius, activePaint);
      }
    } else {
      // Subtle team color ring when inactive
      final teamColor = isTeamA ? KoutTheme.teamAColor : KoutTheme.teamBColor;
      final ringPaint = Paint()
        ..color = teamColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, _radius, ringPaint);
    }

    // Dealer badge (gold circle with D)
    if (isDealer) {
      final dealerCenter = Offset(center.dx + _radius - 6, center.dy - _radius + 6);
      canvas.drawCircle(dealerCenter, 9, Paint()..color = DiwaniyaColors.goldAccent);
      canvas.drawCircle(
        dealerCenter,
        9,
        Paint()
          ..color = DiwaniyaColors.darkWood
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      TextRenderer.drawCentered(canvas, 'D', DiwaniyaColors.nearBlack, dealerCenter, 10);
    }

    // Name pill below avatar
    final pillY = center.dy + _radius + 14;
    final pillColor = isTeamA ? DiwaniyaColors.nameLabelTeamA : DiwaniyaColors.nameLabelTeamB;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, pillY), width: 80, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(pillRect, Paint()..color = pillColor);
    TextRenderer.drawCentered(canvas, _truncateName(playerName), DiwaniyaColors.pureWhite,
      Offset(center.dx, pillY), 11);

    // Bid action label (during bidding)
    if (bidAction != null) {
      final isPass = bidAction == 'pass';
      final label = isPass ? 'PASS' : 'BID $bidAction';
      final labelColor = isPass ? DiwaniyaColors.passRed : DiwaniyaColors.goldAccent;
      TextRenderer.drawCentered(canvas, label, labelColor,
        Offset(center.dx, center.dy + _radius + 36), 9);
    }

  }

  void _drawRopeBorder(Canvas canvas, Offset center) {
    const dashCount = 24;
    const dashAngle = math.pi * 2 / dashCount;
    const dashLength = dashAngle * 0.55;

    for (int ring = 0; ring < 2; ring++) {
      final r = _radius + 6.0 + ring * 3.5;
      final ropePaint = Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.6 - ring * 0.15)
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

  /// Truncates names longer than 8 characters with an ellipsis.
  static String _truncateName(String name) {
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
  }) {
    final wasActive = isActive;
    playerName = name;
    cardCount = cards;
    isActive = active;
    isTeamA = teamA;
    isDealer = dealer;
    this.bidAction = bidAction;

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

  void flashTrickWin() {
    add(_TrickWinFlashComponent(radius: _radius));
  }

  void setBidderGlow(bool bidder, Color? color) {
    isBidder = bidder;
    bidderGlowColor = color;
  }
}

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
    final parent = this.parent;
    final Offset center;
    if (parent is PlayerSeatComponent) {
      center = Offset(parent.size.x / 2, parent.size.y / 2 - 10);
    } else {
      center = Offset.zero;
    }

    final alpha = (_life / 0.4 * 180).toInt().clamp(0, 180);
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = DiwaniyaColors.goldAccent.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

class _GlowPulseComponent extends PositionComponent {
  final double radius;
  double _opacity = 0.4;
  double _elapsed = 0;

  static const double _minOpacity = 0.20;
  static const double _maxOpacity = 0.65;
  static const double _cycleDuration = 1.6;

  _GlowPulseComponent({required this.radius}) : super(anchor: Anchor.center);

  @override
  void onMount() {
    super.onMount();
    final parentSeat = parent as PlayerSeatComponent;
    position = Vector2(parentSeat.size.x / 2, parentSeat.size.y / 2 - 10);
    size = Vector2.all((radius + 12) * 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final t = (_elapsed % _cycleDuration) / _cycleDuration;
    final wave = t < 0.5 ? t * 2 : 2 - t * 2;
    _opacity = _minOpacity + (_maxOpacity - _minOpacity) * wave;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final glowPaint = Paint()
      ..color = DiwaniyaColors.activeTurnRing.withValues(alpha: _opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius + 8, glowPaint);
  }
}
