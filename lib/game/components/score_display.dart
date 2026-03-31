import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../theme/kout_theme.dart';

/// Displays tug-of-war score (center) with trick circles (edges) at the top.
class ScoreDisplayComponent extends PositionComponent {
  ClientGameState? _state;

  static const double _panelHeight = 52.0;
  static const double _panelPadding = 12.0;
  static const double _circleRadius = 7.0;
  static const double _circleSpacing = 20.0;

  int _prevScoreA = 0;
  int _prevScoreB = 0;
  double _pulse = 1.0;

  ScoreDisplayComponent({required double screenWidth})
      : super(
          position: Vector2(0, 0),
          size: Vector2(screenWidth, _panelHeight),
          anchor: Anchor.topLeft,
        );

  void updateState(ClientGameState state) {
    final newScoreA = state.scores[Team.a] ?? 0;
    final newScoreB = state.scores[Team.b] ?? 0;
    if (newScoreA != _prevScoreA || newScoreB != _prevScoreB) _pulse = 1.12;
    _prevScoreA = newScoreA;
    _prevScoreB = newScoreB;
    _state = state;
  }

  @override
  void update(double dt) {
    if (_pulse > 1.0) _pulse = (_pulse - dt * 1.5).clamp(1.0, 1.12);
  }

  @override
  void render(Canvas canvas) {
    // Background panel
    final bgPaint = Paint()
      ..color = KoutTheme.primary.withValues(alpha: 0.85);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, _panelHeight),
      bgPaint,
    );

    // Bottom border accent
    final borderPaint = Paint()
      ..color = KoutTheme.accent.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, _panelHeight - 1),
      Offset(size.x, _panelHeight - 1),
      borderPaint,
    );

    if (_state == null) {
      _drawText(canvas, 'Loading...', KoutTheme.textColor,
          Offset(size.x / 2, _panelHeight / 2), 12, 1.0);
      return;
    }

    final s = _state!;

    // Tug-of-war: only one team has a non-zero score
    final teamAScore = s.scores[Team.a] ?? 0;
    final teamBScore = s.scores[Team.b] ?? 0;
    final tugScore = teamAScore > 0 ? teamAScore : teamBScore;
    final Team? leadingTeam = teamAScore > 0
        ? Team.a
        : teamBScore > 0
            ? Team.b
            : null;
    final scoreColor = leadingTeam == Team.a
        ? KoutTheme.teamAColor
        : leadingTeam == Team.b
            ? KoutTheme.teamBColor
            : KoutTheme.textColor;

    // Trick circles (only during playing/scoring phases)
    final showCircles = s.phase == GamePhase.playing ||
        s.phase == GamePhase.roundScoring;

    if (showCircles && s.bidderUid != null) {
      final bidderSeat = s.playerUids.indexOf(s.bidderUid!);
      if (bidderSeat >= 0) {
        final bidderTeam = teamForSeat(bidderSeat);
        final bidValue = s.currentBid?.value ?? 5;
        final opponentCount = 9 - bidValue;
        final bidderTricks = s.tricks[bidderTeam] ?? 0;
        final opponentTricks = s.tricks[bidderTeam.opponent] ?? 0;

        final bool bidderIsA = bidderTeam == Team.a;
        final leftCount = bidderIsA ? bidValue : opponentCount;
        final rightCount = bidderIsA ? opponentCount : bidValue;
        final leftFilled = bidderIsA ? bidderTricks : opponentTricks;
        final rightFilled = bidderIsA ? opponentTricks : bidderTricks;

        // Left group (Team A) — label then circles
        const labelWidth = 46.0;
        _drawText(canvas, 'Team A', KoutTheme.teamAColor,
            Offset(_panelPadding + labelWidth / 2, _panelHeight / 2 - 3), 9, 1.0);
        _drawCircleGroup(
          canvas,
          startX: _panelPadding + labelWidth + 4,
          centerY: _panelHeight / 2 - 3,
          count: leftCount,
          filled: leftFilled,
          color: KoutTheme.teamAColor,
        );

        // Right group (Team B) — circles then label
        final rightGroupWidth = (rightCount - 1) * _circleSpacing;
        final rightCirclesStart =
            size.x - _panelPadding - labelWidth - 4 - rightGroupWidth;
        _drawCircleGroup(
          canvas,
          startX: rightCirclesStart,
          centerY: _panelHeight / 2 - 3,
          count: rightCount,
          filled: rightFilled,
          color: KoutTheme.teamBColor,
        );
        _drawText(canvas, 'Team B', KoutTheme.teamBColor,
            Offset(size.x - _panelPadding - labelWidth / 2, _panelHeight / 2 - 3), 9, 1.0);
      }
    }

    // Tug-of-war score (centered)
    _drawText(
      canvas,
      '$tugScore',
      scoreColor,
      Offset(size.x / 2, _panelHeight / 2 - 5),
      16,
      _pulse,
    );

    // Phase label (only when not playing — bid/trump now shown on seat)
    if (!showCircles) {
      _drawText(
        canvas,
        _phaseLabel(s.phase.name),
        KoutTheme.textColor.withValues(alpha: 0.6),
        Offset(size.x / 2, _panelHeight / 2 + 10),
        9,
        1.0,
      );
    }

    // Single tug-of-war progress bar
    final barY = size.y - 6;
    const barHeight = 3.0;
    final barWidth = size.x - 16;
    final ratio = (tugScore / 31).clamp(0.0, 1.0);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(8, barY, barWidth, barHeight),
      Paint()..color = KoutTheme.progressBarBg,
    );
    // Fill with leading team color
    canvas.drawRect(
      Rect.fromLTWH(8, barY, barWidth * ratio, barHeight),
      Paint()..color = scoreColor,
    );
  }

  void _drawCircleGroup(
    Canvas canvas, {
    required double startX,
    required double centerY,
    required int count,
    required int filled,
    required Color color,
  }) {
    for (int i = 0; i < count; i++) {
      final cx = startX + i * _circleSpacing;
      final center = Offset(cx, centerY);

      if (i < filled) {
        canvas.drawCircle(center, _circleRadius, Paint()..color = color);
      } else {
        canvas.drawCircle(
          center,
          _circleRadius,
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Color color,
    Offset center,
    double fontSize,
    double scale,
  ) {
    final pb = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.w600))
      ..addText(text);

    final paragraph = pb.build();
    paragraph.layout(ParagraphConstraints(width: size.x * 0.4));

    if (scale != 1.0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - size.x * 0.2, center.dy - fontSize / 2 - 1),
    );

    if (scale != 1.0) {
      canvas.restore();
    }
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'bidding':
        return 'Bidding';
      case 'trumpSelection':
        return 'Select Trump';
      case 'playing':
        return 'Playing';
      case 'scoring':
        return 'Scoring';
      default:
        return phase;
    }
  }

  void updateWidth(double newWidth) {
    size = Vector2(newWidth, _panelHeight);
  }
}
