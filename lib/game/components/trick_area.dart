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
      ..color = KoutTheme.table.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(layout.trickCenter.x, layout.trickCenter.y),
      70,
      paint,
    );

    final borderPaint = Paint()
      ..color = KoutTheme.accent.withValues(alpha: 0.3)
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

    for (int i = 0; i < state.currentTrickPlays.length; i++) {
      final play = state.currentTrickPlays[i];
      final absoluteSeat = state.playerUids.indexOf(play.playerUid);
      if (absoluteSeat < 0) continue;

      final relativeSeat =
          layout.toRelativeSeat(absoluteSeat, mySeatIndex);
      final basePos = layout.trickCardPosition(relativeSeat);

      // Nudge later cards toward center so they visually stack/overlap,
      // making play order obvious at a glance.
      final center = layout.trickCenter;
      final nudgeFactor = i * 0.06; // each successive card drifts ~6% inward
      final pos = basePos + (center - basePos) * nudgeFactor;

      // Slight rotation per seat for visual variety
      final angle = _seatAngle(relativeSeat);

      // Later cards get higher priority (z-order) so play order is
      // visually obvious — the most recent card renders on top.
      final cardComp = CardComponent(
        card: play.card,
        isFaceUp: true,
        isHighlighted: false,
        position: pos,
        angle: angle,
      )..priority = i;

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
