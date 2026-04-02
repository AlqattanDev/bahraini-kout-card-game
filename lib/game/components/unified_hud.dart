import 'dart:ui';
import 'package:flame/components.dart';
import '../../shared/models/game_state.dart';
import '../../shared/models/card.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/kout_theme.dart';
import '../theme/text_renderer.dart';

/// Unified top-right HUD panel combining score, round, bid/trump, trick pips, and game timer.
class UnifiedHudComponent extends PositionComponent {
  static const double _hudWidth = 160.0;
  static const double _pipRadius = 4.5;
  static const double _pipSpacing = 13.0;
  static const double _dividerHeight = 1.0;
  static const double _padding = 12.0;
  static const double _rowGap = 6.0;

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
  String timerText = '00:00';

  UnifiedHudComponent({required double screenWidth})
      : super(
          position: Vector2(screenWidth - _hudWidth - 12, 10),
          size: Vector2(_hudWidth, 80),
          anchor: Anchor.topLeft,
        );

  void updateWidth(double newWidth) {
    position = Vector2(newWidth - _hudWidth - 12, 10);
  }

  void updateState({
    required GamePhase phase,
    required int teamAScore,
    required int teamBScore,
    required int roundNumber,
    int? bidValue,
    Team? bidderTeam,
    Suit? trumpSuit,
    int bidderTricks = 0,
    int opponentTricks = 0,
    int opponentTarget = 0,
  }) {
    _phase = phase;
    this.roundNumber = roundNumber;
    this.bidValue = bidValue;
    this.bidderTeam = bidderTeam;
    this.trumpSuit = trumpSuit;
    this.bidderTricks = bidderTricks;
    this.opponentTricks = opponentTricks;
    this.opponentTarget = opponentTarget;

    if (teamAScore > 0) {
      score = teamAScore;
      scoreColor = KoutTheme.teamAColor;
    } else if (teamBScore > 0) {
      score = teamBScore;
      scoreColor = KoutTheme.teamBColor;
    } else {
      score = 0;
      scoreColor = DiwaniyaColors.cream;
    }
  }

  void updateTimer(Duration elapsed) {
    final totalSeconds = elapsed.inSeconds.clamp(0, 3599);
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    timerText = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static int computePips({required int target, required int tricksTaken}) {
    return tricksTaken.clamp(0, target);
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
    h += 30;
    h += _rowGap;
    h += _dividerHeight;
    h += _rowGap;
    if (_showBidRow) {
      h += 18;
      h += _rowGap;
    }
    if (_showPips) {
      h += 16 + 16;
      h += _rowGap;
      h += _dividerHeight;
      h += _rowGap;
    }
    h += 16;
    h += _padding;
    return h;
  }

  @override
  void render(Canvas canvas) {
    final hudHeight = _computeHeight();
    size = Vector2(_hudWidth, hudHeight);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, hudHeight),
      const Radius.circular(12),
    );
    canvas.drawRRect(bgRect, Paint()..color = DiwaniyaColors.scoreHudBg);
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = DiwaniyaColors.scoreHudBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    double y = _padding;

    TextRenderer.draw(canvas, '$score', scoreColor,
        Offset(_padding, y), 28, align: TextAlign.left, width: 60);
    TextRenderer.draw(canvas, '/ 31',
        DiwaniyaColors.cream.withValues(alpha: 0.5),
        Offset(_padding + 50, y + 10), 11, align: TextAlign.left, width: 40);
    TextRenderer.draw(canvas, 'R$roundNumber',
        DiwaniyaColors.cream.withValues(alpha: 0.5),
        Offset(_hudWidth - _padding - 30, y + 10), 11,
        align: TextAlign.right, width: 30);
    y += 30 + _rowGap;

    canvas.drawLine(
      Offset(_padding, y),
      Offset(_hudWidth - _padding, y),
      Paint()..color = DiwaniyaColors.scoreHudBorder,
    );
    y += _dividerHeight + _rowGap;

    if (_showBidRow && bidValue != null) {
      final bidTeamColor = bidderTeam == Team.a
          ? KoutTheme.teamAColor
          : bidderTeam == Team.b
              ? KoutTheme.teamBColor
              : DiwaniyaColors.cream;

      final bidText = bidValue == 8 ? 'KOUT' : 'BID $bidValue';
      TextRenderer.draw(canvas, bidText, bidTeamColor,
          Offset(_padding, y), 12, align: TextAlign.left, width: 80);

      if (trumpSuit != null) {
        final suitSymbol = _suitSymbol(trumpSuit!);
        final suitColor = (trumpSuit == Suit.hearts || trumpSuit == Suit.diamonds)
            ? const Color(0xFFCC3333)
            : DiwaniyaColors.cream;
        TextRenderer.draw(canvas, suitSymbol, suitColor,
            Offset(_hudWidth - _padding - 16, y), 14,
            align: TextAlign.right, width: 16);
      }
      y += 18 + _rowGap;
    }

    if (_showPips && bidValue != null) {
      final bidTeamColor = bidderTeam == Team.a
          ? KoutTheme.teamAColor
          : KoutTheme.teamBColor;
      final oppTeamColor = bidderTeam == Team.a
          ? KoutTheme.teamBColor
          : KoutTheme.teamAColor;

      _drawPipRow(canvas, y + 4, bidValue!, bidderTricks, bidTeamColor);
      y += 16;
      _drawPipRow(canvas, y + 4, opponentTarget, opponentTricks, oppTeamColor);
      y += 16 + _rowGap;

      canvas.drawLine(
        Offset(_padding, y),
        Offset(_hudWidth - _padding, y),
        Paint()..color = DiwaniyaColors.scoreHudBorder,
      );
      y += _dividerHeight + _rowGap;
    }

    TextRenderer.draw(canvas, timerText,
        DiwaniyaColors.cream.withValues(alpha: 0.65),
        Offset(_hudWidth / 2, y), 12,
        align: TextAlign.center, width: _hudWidth);
  }

  void _drawPipRow(Canvas canvas, double y, int total, int filled, Color color) {
    final clamped = filled.clamp(0, total);
    final totalWidth = (total - 1) * _pipSpacing;
    final startX = (_hudWidth - totalWidth) / 2;

    for (int i = 0; i < total; i++) {
      final cx = startX + i * _pipSpacing;
      if (i < clamped) {
        canvas.drawCircle(Offset(cx, y), _pipRadius, Paint()..color = color);
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

  static String _suitSymbol(Suit suit) {
    const symbols = {
      Suit.spades: '♠',
      Suit.hearts: '♥',
      Suit.clubs: '♣',
      Suit.diamonds: '♦',
    };
    return symbols[suit] ?? '?';
  }
}
