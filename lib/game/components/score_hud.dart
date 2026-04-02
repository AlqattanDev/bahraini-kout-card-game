import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/game_state.dart';
import '../theme/diwaniya_colors.dart';
import '../theme/kout_theme.dart';

/// Compact score display positioned top-right.
class ScoreHudComponent extends PositionComponent {
  ClientGameState? _state;

  static const double _hudWidth = 140.0;
  static const double _hudHeight = 80.0;
  static const double _pipRadius = 4.5;
  static const double _pipSpacing = 13.0;

  ScoreHudComponent({required double screenWidth})
      : super(
          position: Vector2(screenWidth - _hudWidth - 12, 10),
          size: Vector2(_hudWidth, _hudHeight),
          anchor: Anchor.topLeft,
        );

  void updateState(ClientGameState state) {
    _state = state;
  }

  void updateWidth(double newWidth) {
    position = Vector2(newWidth - _hudWidth - 12, 10);
  }

  static int computePips({required int bidValue, required int tricksTaken}) {
    return tricksTaken.clamp(0, 8);
  }

  @override
  void render(Canvas canvas) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _hudWidth, _hudHeight),
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

    if (_state == null) return;
    final s = _state!;

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
            : DiwaniyaColors.cream;

    _drawText(canvas, '$tugScore', scoreColor, Offset(_hudWidth / 2 - 10, 8), 28);
    _drawText(canvas, '/ 31', DiwaniyaColors.cream.withValues(alpha: 0.5), Offset(_hudWidth / 2 + 25, 18), 11);

    final showPips = s.phase == GamePhase.playing || s.phase == GamePhase.roundScoring;
    if (showPips && s.bidderUid != null) {
      final bidderSeat = s.playerUids.indexOf(s.bidderUid!);
      if (bidderSeat >= 0) {
        final bidderTeam = teamForSeat(bidderSeat);
        final bidValue = s.currentBid?.value ?? 5;
        final bidderTricks = s.tricks[bidderTeam] ?? 0;
        final opponentTricks = s.tricks[bidderTeam.opponent] ?? 0;
        final opponentTarget = 9 - bidValue;

        _drawPipRow(canvas, 48, bidValue, bidderTricks,
            bidderTeam == Team.a ? KoutTheme.teamAColor : KoutTheme.teamBColor);
        _drawPipRow(canvas, 64, opponentTarget, opponentTricks,
            bidderTeam == Team.a ? KoutTheme.teamBColor : KoutTheme.teamAColor);
      }
    }
  }

  void _drawPipRow(Canvas canvas, double y, int total, int filled, Color color) {
    final totalWidth = (total - 1) * _pipSpacing;
    final startX = (_hudWidth - totalWidth) / 2;

    for (int i = 0; i < total; i++) {
      final cx = startX + i * _pipSpacing;
      if (i < filled) {
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

  void _drawText(Canvas canvas, String text, Color color, Offset offset, double fontSize) {
    final pb = ParagraphBuilder(
      ParagraphStyle(fontSize: fontSize, fontFamily: 'IBMPlexMono'),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.bold))
      ..addText(text);
    final paragraph = pb.build();
    paragraph.layout(const ParagraphConstraints(width: 100));
    canvas.drawParagraph(paragraph, offset);
  }
}
