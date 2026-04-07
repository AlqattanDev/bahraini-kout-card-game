import 'dart:ui';
import 'package:flame/components.dart';
import 'dart:math' as math;
import '../../app/models/client_game_state.dart';
import '../../shared/constants.dart';
import '../../shared/models/game_state.dart';
import '../../shared/models/card.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/kout_theme.dart';
import '../theme/text_renderer.dart';

/// Compact HUD: score+round, bid+trump, trick pips (both teams on one line), timer.
class UnifiedHudComponent extends PositionComponent {
  static const double _hudWidth = 155.0;
  static const double _padding = 10.0;
  static const double _rowGap = 4.0;
  static const double _pipRadius = 3.5;
  static const double _pipSpacing = 10.0;

  // Public state — set via updateState() and updateTimer()
  int score = 0;
  Color scoreColor = DiwaniyaColors.cream;
  int roundNumber = 1;
  int? bidValue;
  Team? bidderTeam;
  Suit? trumpSuit;
  int bidderTricks = 0;
  int opponentTricks = 0;
  int opponentTarget = 0;
  GamePhase _phase = GamePhase.waiting;
  bool _isLandscape = false;
  String timerText = '00:00';
  
  // Animation state
  int _prevTricksA = 0;
  int _prevTricksB = 0;
  double _pipAnimTimer = 0.0;
  double _displayScore = 0.0;
  int _targetScore = 0;
  int _elapsedSeconds = 0;

  UnifiedHudComponent({required double screenWidth})
      : super(
          position: Vector2(screenWidth - _hudWidth - 12, 10),
          size: Vector2(_hudWidth, 80),
          anchor: Anchor.topLeft,
        );

  void updateWidth(double newWidth) {
    position = Vector2(newWidth - _hudWidth - 12, 10);
  }

  void updateLayout(double screenWidth,
      {double rightInset = 0,
      double topInset = 0,
      bool landscape = false,
      double leftInset = 0}) {
    _isLandscape = landscape;
    if (landscape) {
      position = Vector2(leftInset + 12, 10 + topInset);
    } else {
      position = Vector2(screenWidth - _hudWidth - 12 - rightInset, 10 + topInset);
    }
  }

  void updateState(ClientGameState state) {
    _phase = state.phase;
    final teamAScore = state.scores[Team.a] ?? 0;
    final teamBScore = state.scores[Team.b] ?? 0;
    roundNumber = (state.trickWinners.length ~/ tricksPerRound) + 1;

    final bt = state.bidderTeam;
    bidderTeam = bt;
    trumpSuit = state.trumpSuit;

    if (bt != null && state.currentBid != null) {
      bidValue = state.currentBid!.value;
      bidderTricks = state.tricks[bt] ?? 0;
      opponentTricks = state.tricks[bt.opponent] ?? 0;
      opponentTarget = (tricksPerRound + 1) - bidValue!;
    } else {
      bidValue = null;
      bidderTricks = 0;
      opponentTricks = 0;
      opponentTarget = 0;
    }

    _targetScore = teamAScore > 0 ? teamAScore : teamBScore;
    score = _targetScore; // Keep score updated for backward compatibility and tests
    if (_displayScore == 0.0 && _targetScore > 0) {
      _displayScore = _targetScore.toDouble(); // Initial snap
    }
    scoreColor = teamAScore > 0
        ? KoutTheme.teamAColor
        : teamBScore > 0
            ? KoutTheme.teamBColor
            : DiwaniyaColors.cream;
            
    final currentTricksA = state.tricks[Team.a] ?? 0;
    final currentTricksB = state.tricks[Team.b] ?? 0;
    if (currentTricksA > _prevTricksA || currentTricksB > _prevTricksB) {
      _pipAnimTimer = 0.3;
    }
    _prevTricksA = currentTricksA;
    _prevTricksB = currentTricksB;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pipAnimTimer > 0) {
      _pipAnimTimer = math.max(0.0, _pipAnimTimer - dt);
    }
    _displayScore += (_targetScore - _displayScore) * math.min(1.0, dt * 8.0);
  }

  void updateTimer(Duration elapsed) {
    final totalSeconds = elapsed.inSeconds.clamp(0, 3599);
    _elapsedSeconds = totalSeconds;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    timerText = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _showBidRow =>
      _phase == GamePhase.trumpSelection ||
      _phase == GamePhase.bidAnnouncement ||
      _phase == GamePhase.playing ||
      _phase == GamePhase.roundScoring;

  bool get _showPips =>
      _phase == GamePhase.playing || _phase == GamePhase.roundScoring;

  double _computeHeight() {
    double h = _padding;
    h += 24; // score + round row
    h += _rowGap + 1 + _rowGap; // divider
    if (_showBidRow) {
      h += 18; // bid + trump row
      h += _rowGap;
    }
    if (_showPips) {
      h += 14; // pip rows (both teams, one line)
      h += _rowGap + 1 + _rowGap; // divider
    }
    h += 14; // timer
    h += 8; // bottom padding
    return h;
  }

  @override
  void render(Canvas canvas) {
    final hudHeight = _computeHeight();
    size = Vector2(_hudWidth, hudHeight);

    // --- Background ---
    final bgColor =
        _isLandscape ? DiwaniyaColors.hudBgLandscape : DiwaniyaColors.scoreHudBg;
    final borderColor =
        _isLandscape ? DiwaniyaColors.hudBorderLandscape : DiwaniyaColors.scoreHudBorder;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, hudHeight),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      bgRect.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(bgRect, Paint()..color = bgColor);

    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, _hudWidth - 2, hudHeight * 0.35),
      const Radius.circular(11),
    );
    canvas.drawRRect(highlightRect, Paint()..color = const Color(0x08FFFFFF));

    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    double y = _padding;
    final rightEdge = _hudWidth - _padding;

    // --- Row 1: Score + Round (one line) ---
    TextRenderer.draw(canvas, '${_displayScore.round()}', scoreColor, Offset(_padding, y), 22,
        align: TextAlign.left, width: 50);
    TextRenderer.draw(
        canvas,
        '/ $targetScore',
        DiwaniyaColors.cream.withValues(alpha: 0.4),
        Offset(_padding + 48, y + 8),
        11,
        align: TextAlign.left,
        width: 30);
    TextRenderer.draw(canvas, 'R$roundNumber', DiwaniyaColors.hudLabelMuted,
        Offset(rightEdge - 20, y + 2), 9,
        align: TextAlign.right, width: 20);
    y += 24 + _rowGap;

    // Divider
    _drawDivider(canvas, y);
    y += 1 + _rowGap;

    // --- Row 2: Bidder team + BID value + Trump suit ---
    if (_showBidRow && bidValue != null) {
      final bidTeamColor =
          bidderTeam != null ? KoutTheme.teamColor(bidderTeam!) : DiwaniyaColors.cream;
      final bidTeamLetter = bidderTeam == Team.a ? 'A' : 'B';

      // "A BID 5" or "B KOUT" in team color
      final bidText = bidValue == 8 ? '$bidTeamLetter KOUT' : '$bidTeamLetter BID $bidValue';
      TextRenderer.draw(canvas, bidText, bidTeamColor, Offset(_padding, y), 12,
          align: TextAlign.left, width: 90);

      // Trump suit — large and colored
      if (trumpSuit != null) {
        final suitColor = KoutTheme.suitHudColor(trumpSuit!);
        TextRenderer.draw(canvas, trumpSuit!.symbol, suitColor,
            Offset(rightEdge - 22, y - 3), 20,
            align: TextAlign.right, width: 22);
      }
      y += 18 + _rowGap;
    }

    // --- Row 3: Both pip rows on ONE line ---
    if (_showPips && bidValue != null) {
      final bidTeamColor = KoutTheme.teamColor(bidderTeam ?? Team.a);
      final oppTeamColor = KoutTheme.teamColor((bidderTeam ?? Team.a).opponent);
      final bidTeamLabel = bidderTeam == Team.a ? 'A' : 'B';
      final oppTeamLabel = bidderTeam == Team.a ? 'B' : 'A';

      // Bidder pips on left half
      double x = _padding;
      TextRenderer.draw(canvas, bidTeamLabel, bidTeamColor, Offset(x, y), 9,
          align: TextAlign.left, width: 10);
      x += 14;
      _drawPipsInline(canvas, x, y + 4, bidValue!, bidderTricks, bidTeamColor);
      x += bidValue! * _pipSpacing + 4;

      // Opponent pips on right half
      TextRenderer.draw(canvas, oppTeamLabel, oppTeamColor, Offset(x, y), 9,
          align: TextAlign.left, width: 10);
      x += 14;
      _drawPipsInline(canvas, x, y + 4, opponentTarget, opponentTricks, oppTeamColor);

      y += 14 + _rowGap;

      _drawDivider(canvas, y);
      y += 1 + _rowGap;
    }

    // --- Row 4: Timer ---
    Color timerColor;
    if (_elapsedSeconds >= 55) {
      timerColor = KoutTheme.lossColor.withValues(alpha: 0.9);
    } else if (_elapsedSeconds >= 45) {
      timerColor = DiwaniyaColors.goldAccent.withValues(alpha: 0.7);
    } else {
      timerColor = DiwaniyaColors.cream.withValues(alpha: 0.45);
    }

    TextRenderer.draw(
        canvas,
        timerText,
        timerColor,
        Offset(_hudWidth / 2, y),
        10,
        align: TextAlign.center,
        width: _hudWidth);
  }

  void _drawDivider(Canvas canvas, double y) {
    canvas.drawLine(
      Offset(_padding, y),
      Offset(_hudWidth - _padding, y),
      Paint()..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.20),
    );
  }

  void _drawPipsInline(
      Canvas canvas, double startX, double y, int total, int filled, Color color) {
    final clamped = filled.clamp(0, total);
    for (int i = 0; i < total; i++) {
      final cx = startX + i * _pipSpacing;
      if (i < clamped) {
        double radius = _pipRadius;
        if (i == clamped - 1 && _pipAnimTimer > 0) {
          final t = 1.0 - (_pipAnimTimer / 0.3);
          radius = _pipRadius * (1.0 + 0.8 * (1.0 - t));
        }
        canvas.drawCircle(Offset(cx, y), radius, Paint()..color = color);
      } else {
        canvas.drawCircle(
          Offset(cx, y),
          _pipRadius,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }
}
