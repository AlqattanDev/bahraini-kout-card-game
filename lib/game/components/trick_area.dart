import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/card.dart';
import '../managers/layout_manager.dart';
import '../theme/kout_theme.dart';
import 'card_component.dart';

/// Displays the 0–4 cards currently played in the center trick area.
///
/// Cards are positioned by relative seat (0=bottom/me, 1=left, 2=top, 3=right).
class TrickAreaComponent extends Component {
  final LayoutManager layout;
  final int mySeatIndex;

  final List<CardComponent> _trickCards = [];

  TrickAreaComponent({
    required this.layout,
    required this.mySeatIndex,
  });

  @override
  void render(Canvas canvas) {
    // Draw a subtle felt circle in the center
    final paint = Paint()
      ..color = KoutTheme.table.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(layout.trickCenter.x, layout.trickCenter.y),
      70,
      paint,
    );

    final borderPaint = Paint()
      ..color = KoutTheme.accent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(layout.trickCenter.x, layout.trickCenter.y),
      70,
      borderPaint,
    );
  }

  /// Rebuilds trick cards from [state.currentTrickPlays].
  void updateState(ClientGameState state) {
    for (final c in _trickCards) {
      c.removeFromParent();
    }
    _trickCards.clear();

    for (final play in state.currentTrickPlays) {
      final absoluteSeat = state.playerUids.indexOf(play.playerUid);
      if (absoluteSeat < 0) continue;

      final relativeSeat =
          layout.toRelativeSeat(absoluteSeat, mySeatIndex);
      final pos = layout.trickCardPosition(relativeSeat);

      // Slight rotation per seat for visual variety
      final angle = _seatAngle(relativeSeat);

      final cardComp = CardComponent(
        card: play.card,
        isFaceUp: true,
        isHighlighted: false,
        position: pos,
        angle: angle,
      );

      _trickCards.add(cardComp);
      add(cardComp);
    }
  }

  double _seatAngle(int relativeSeat) {
    switch (relativeSeat) {
      case 1:
        return 0.1;
      case 2:
        return 0.05;
      case 3:
        return -0.1;
      default:
        return 0.0;
    }
  }

  void updateLayout(LayoutManager newLayout) {
    // Re-position existing cards if layout changes (e.g. resize)
    // Simple approach: trigger a full rebuild on next updateState call
  }
}
