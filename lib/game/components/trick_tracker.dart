import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../theme/kout_theme.dart';

class TrickTrackerComponent extends PositionComponent {
  static const _circleRadius = 10.0;
  static const _spacing = 26.0;

  int _bidderTricks = 0;
  int _opponentTricks = 0;
  Team _bidderTeam = Team.a;
  int _bidValue = 5;
  bool _visible = false;

  /// Horizontal offset from center for each team's group.
  final double groupOffset;

  TrickTrackerComponent({
    required Vector2 position,
    this.groupOffset = 120.0,
  }) : super(position: position, anchor: Anchor.center);

  void updateState(ClientGameState state) {
    _bidValue = state.currentBid?.value ?? 5;
    _visible = state.phase == GamePhase.playing ||
        state.phase == GamePhase.roundScoring;

    if (state.bidderUid != null) {
      final bidderSeat = state.playerUids.indexOf(state.bidderUid!);
      if (bidderSeat >= 0) {
        _bidderTeam = teamForSeat(bidderSeat);
        _bidderTricks = state.tricks[_bidderTeam] ?? 0;
        _opponentTricks = state.tricks[_bidderTeam.opponent] ?? 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_visible) return;

    final bidderCount = _bidValue;
    final opponentCount = 9 - _bidValue;

    final bidderColor =
        _bidderTeam == Team.a ? KoutTheme.teamAColor : KoutTheme.teamBColor;
    final opponentColor =
        _bidderTeam == Team.a ? KoutTheme.teamBColor : KoutTheme.teamAColor;

    // Team A group on left, Team B group on right
    final bool bidderOnLeft = _bidderTeam == Team.a;
    final leftCount = bidderOnLeft ? bidderCount : opponentCount;
    final rightCount = bidderOnLeft ? opponentCount : bidderCount;
    final leftColor = KoutTheme.teamAColor;
    final rightColor = KoutTheme.teamBColor;
    final leftFilled = bidderOnLeft ? _bidderTricks : _opponentTricks;
    final rightFilled = bidderOnLeft ? _opponentTricks : _bidderTricks;

    // Draw left group (Team A)
    _drawGroup(canvas, -groupOffset, leftCount, leftFilled, leftColor);

    // Draw right group (Team B)
    _drawGroup(canvas, groupOffset, rightCount, rightFilled, rightColor);
  }

  void _drawGroup(
    Canvas canvas,
    double centerX,
    int totalCircles,
    int filledCircles,
    Color teamColor,
  ) {
    final groupWidth = (totalCircles - 1) * _spacing;
    final startX = centerX - groupWidth / 2;

    for (int i = 0; i < totalCircles; i++) {
      final cx = startX + i * _spacing;
      final center = Offset(cx, 0);

      if (i < filledCircles) {
        // Filled circle — trick won
        canvas.drawCircle(center, _circleRadius, Paint()..color = teamColor);
      } else {
        // Empty circle — outlined in team color
        canvas.drawCircle(
          center,
          _circleRadius,
          Paint()
            ..color = teamColor.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }
}
