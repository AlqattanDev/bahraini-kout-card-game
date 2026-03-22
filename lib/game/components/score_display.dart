import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/game_state.dart';
import '../theme/kout_theme.dart';

/// Displays team scores, current bid, trump suit, and trick counts at the top.
class ScoreDisplayComponent extends PositionComponent {
  ClientGameState? _state;

  static const double _panelHeight = 44.0;
  static const double _panelPadding = 12.0;

  ScoreDisplayComponent({required double screenWidth})
      : super(
          position: Vector2(0, 0),
          size: Vector2(screenWidth, _panelHeight),
          anchor: Anchor.topLeft,
        );

  void updateState(ClientGameState state) {
    _state = state;
  }

  @override
  void render(Canvas canvas) {
    // Background panel
    final bgPaint = Paint()
      ..color = KoutTheme.primary.withOpacity(0.85);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, _panelHeight),
      bgPaint,
    );

    // Bottom border accent
    final borderPaint = Paint()
      ..color = KoutTheme.accent.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, _panelHeight - 1),
      Offset(size.x, _panelHeight - 1),
      borderPaint,
    );

    if (_state == null) {
      _drawText(canvas, 'Loading...', KoutTheme.textColor,
          Offset(size.x / 2, _panelHeight / 2), 12);
      return;
    }

    final s = _state!;

    // Team A score (left side)
    final teamAScore = s.scores[Team.a] ?? 0;
    final teamATricks = s.tricks[Team.a] ?? 0;
    _drawText(
      canvas,
      'Team A  $teamAScore pts  (${teamATricks}t)',
      KoutTheme.teamAColor,
      Offset(_panelPadding + 60, _panelHeight / 2),
      11,
    );

    // Team B score (right side)
    final teamBScore = s.scores[Team.b] ?? 0;
    final teamBTricks = s.tricks[Team.b] ?? 0;
    _drawText(
      canvas,
      'Team B  $teamBScore pts  (${teamBTricks}t)',
      KoutTheme.teamBColor,
      Offset(size.x - _panelPadding - 80, _panelHeight / 2),
      11,
    );

    // Center: bid info and trump
    final centerParts = <String>[];

    if (s.currentBid != null) {
      final bidLabel = s.currentBid!.isKout ? 'KOUT' : '${s.currentBid!.value}';
      centerParts.add('Bid: $bidLabel');
    }

    if (s.trumpSuit != null) {
      centerParts.add('Trump: ${_suitSymbol(s.trumpSuit!)}');
    }

    if (centerParts.isEmpty) {
      centerParts.add(_phaseLabel(s.phase.name));
    }

    _drawText(
      canvas,
      centerParts.join('  |  '),
      KoutTheme.textColor,
      Offset(size.x / 2, _panelHeight / 2),
      11,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Color color,
    Offset center,
    double fontSize,
  ) {
    final pb = ParagraphBuilder(
      ParagraphStyle(textAlign: TextAlign.center, fontSize: fontSize),
    )
      ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.w600))
      ..addText(text);

    final paragraph = pb.build();
    paragraph.layout(ParagraphConstraints(width: size.x * 0.4));

    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - size.x * 0.2, center.dy - fontSize / 2 - 1),
    );
  }

  String _suitSymbol(Suit suit) {
    const symbols = {
      Suit.spades: '♠',
      Suit.hearts: '♥',
      Suit.clubs: '♣',
      Suit.diamonds: '♦',
    };
    return symbols[suit] ?? '?';
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
