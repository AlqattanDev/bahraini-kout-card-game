import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../theme/kout_theme.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/text_renderer.dart';
import 'avatar_painter.dart';
import 'painters/bid_label_painter.dart';

/// Displays a player seat: avatar, name pill, gold rope border,
/// and an active-turn team-colored ring.
class PlayerSeatComponent extends PositionComponent {
  String playerName;
  int cardCount;
  bool isActive;
  Team team;
  final int avatarSeed;
  String? bidAction;
  bool isBidder = false;
  Color? bidderGlowColor;
  double timerProgress;
  // Card count badge removed — not needed in current layout

  static const double _radius = 36.0;

  _GlowPulseComponent? _glowPulse;

  final int seatIndex;

  PlayerSeatComponent({
    required this.seatIndex,
    required this.playerName,
    required this.cardCount,
    required this.isActive,
    required this.team,
    this.avatarSeed = 0,
    this.bidAction,
    this.timerProgress = 0.0,
    super.position,
    super.anchor = Anchor.center,
  }) : super(size: Vector2(_radius * 2 + 24, _radius * 2 + 32));

  @override
  void onMount() {
    super.onMount();
    _updateGlowPulse();
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2 - 10);

    _drawRopeBorder(canvas, center);

    if (isBidder && bidderGlowColor != null) {
      final glowPaint = Paint()
        ..color = bidderGlowColor!.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, _radius + 6, glowPaint);
    }

    if (isBidder) {
      _drawCrown(canvas, Offset(center.dx, center.dy - _radius - 24));
    }

    AvatarPainter.paint(canvas, center, _radius - 3, AvatarTraits.fromSeed(avatarSeed));

    final teamColor = KoutTheme.teamColor(team);
    if (isActive) {
      final activeColor = teamColor;
      if (timerProgress > 0.0) {
        final bgRingPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        canvas.drawCircle(center, _radius, bgRingPaint);

        final sweepAngle = timerProgress * math.pi * 2;
        final timerPaint = Paint()
          ..color = activeColor
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
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        canvas.drawCircle(center, _radius, activePaint);
      }
    } else {
      final ringPaint = Paint()
        ..color = teamColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, _radius, ringPaint);
    }

    final pillY = center.dy + _radius - 2;
    final pillColor = team == Team.a ? DiwaniyaColors.nameLabelTeamA : DiwaniyaColors.nameLabelTeamB;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, pillY), width: 80, height: 20),
      const Radius.circular(10),
    );
    // Subtle shadow behind pill
    canvas.drawRRect(
      pillRect.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(pillRect, Paint()..color = pillColor);
    // Thin highlight border
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = const Color(0x15FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    final teamLetter = team == Team.a ? 'A' : 'B';
    final displayName = '$teamLetter  ${_truncateName(playerName)}';
    TextRenderer.drawCentered(canvas, displayName, DiwaniyaColors.pureWhite,
      Offset(center.dx, pillY), 9);

    BidLabelPainter.paint(
      canvas,
      bidAction: bidAction,
      offset: Offset(center.dx, center.dy + _radius + 16),
    );

  }

  /// Draws a geometric crown at [crownCenter] with gold glow.
  static void _drawCrown(Canvas canvas, Offset crownCenter) {
    const double crownWidth = 28.0;
    const double crownHeight = 18.0;
    const double w = crownWidth;
    const double h = crownHeight;
    final left = crownCenter.dx - w / 2;
    final top = crownCenter.dy - h / 2;

    final path = Path()
      // Base
      ..moveTo(left, top + h)
      ..lineTo(left + w, top + h)
      // Right side up to right peak
      ..lineTo(left + w, top + h * 0.4)
      // Right peak
      ..lineTo(left + w * 0.82, top)
      // Valley between right and center
      ..lineTo(left + w * 0.65, top + h * 0.35)
      // Center peak
      ..lineTo(left + w * 0.5, top)
      // Valley between center and left
      ..lineTo(left + w * 0.35, top + h * 0.35)
      // Left peak
      ..lineTo(left + w * 0.18, top)
      // Left side
      ..lineTo(left, top + h * 0.4)
      ..close();

    // Gold glow behind crown
    canvas.drawCircle(
      crownCenter,
      crownWidth * 0.6,
      Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Gold fill
    canvas.drawPath(path, Paint()..color = DiwaniyaColors.goldAccent);
    // Gold highlight on top portion
    canvas.drawPath(
      path,
      Paint()
        ..color = DiwaniyaColors.goldHighlight.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    // Darker stroke outline
    canvas.drawPath(
      path,
      Paint()
        ..color = DiwaniyaColors.darkWood
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
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

  void updateState(ClientGameState state) {
    final uid = state.playerUids[seatIndex];
    final wasActive = isActive;
    playerName = shortUid(uid);
    cardCount = state.cardCounts[seatIndex] ??
        (seatIndex == state.mySeatIndex ? state.myHand.length : 8);
    isActive = state.currentPlayerUid == uid;
    team = teamForSeat(seatIndex);

    // Determine bid action from bid history during bidding/trump phases
    if (state.phase == GamePhase.bidding || state.phase == GamePhase.trumpSelection) {
      String? action;
      for (final entry in state.bidHistory) {
        if (entry.playerUid == uid) action = entry.action;
      }
      bidAction = action;
    } else {
      bidAction = null;
    }

    if (wasActive != isActive && isMounted) {
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
    final parentSeat = parent as PlayerSeatComponent;
    final Offset center = Offset(parentSeat.size.x / 2, parentSeat.size.y / 2 - 10);

    final alpha = (_life / 0.4).clamp(0.0, 1.0) * 0.7;
    canvas.drawCircle(
      center,
      radius + 6,
      Paint()
        ..color = DiwaniyaColors.goldAccent.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }
}

class _GlowPulseComponent extends PositionComponent {
  final double radius;
  double _opacity = 0.4;
  double _elapsed = 0;

  static const double _minOpacity = 0.30;
  static const double _maxOpacity = 0.80;
  static const double _cycleDuration = 1.4;

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
    final parentSeat = parent as PlayerSeatComponent;
    final teamColor = KoutTheme.teamColor(parentSeat.team);
    final glowPaint = Paint()
      ..color = teamColor.withValues(alpha: _opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, radius + 12, glowPaint);
  }
}
