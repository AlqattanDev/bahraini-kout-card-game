import 'dart:math' as math;

import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/logic/card_utils.dart';
import '../managers/layout_manager.dart';
import 'card_component.dart';

/// Face-up mini fans for each opponent when [ClientGameState.debugAllHands] is set
/// (offline + debug build only).
class DebugOpponentHandsOverlay extends Component {
  static const double _miniRestScale = 0.38;

  /// Clears and rebuilds opponent hand visuals from [state].
  void updateState(ClientGameState state, LayoutManager layout) {
    for (final c in List<Component>.from(children)) {
      c.removeFromParent();
    }

    final hands = state.debugAllHands;
    if (hands == null) return;

    final myIndex = state.mySeatIndex;

    for (int seat = 0; seat < 4; seat++) {
      if (seat == myIndex) continue;

      final uid = state.playerUids[seat];
      final rawHand = hands[uid];
      if (rawHand == null || rawHand.isEmpty) continue;

      final sorted = sortHandForDisplay(rawHand, state.trumpSuit);
      final relativeSeat = layout.toRelativeSeat(seat, myIndex);
      final seatPos = layout.seatPosition(seat, myIndex);
      final offset = _fanOffset(relativeSeat);
      final baseRotation = _baseRotation(relativeSeat);

      final group = PositionComponent(
        position: seatPos + offset,
        angle: baseRotation,
        anchor: Anchor.center,
      );
      add(group);

      final positions = _centeredFan(sorted.length);
      for (int i = 0; i < sorted.length; i++) {
        final p = positions[i];
        group.add(
          CardComponent(
            card: sorted[i],
            isFaceUp: true,
            isHighlighted: false,
            isDimmed: false,
            showShadow: false,
            restScale: _miniRestScale,
            position: p.position,
            angle: p.angle,
            anchor: Anchor.center,
          )..scale = Vector2.all(_miniRestScale),
        );
      }
    }
  }

  static List<({Vector2 position, double angle})> _centeredFan(int cardCount) {
    if (cardCount == 0) return [];

    const maxFanAngle = 0.55;
    final cardSpacing = (42.0 - cardCount * 1.5).clamp(22.0, 36.0);
    final totalWidth = (cardCount - 1) * cardSpacing;
    final startX = -totalWidth / 2;
    const arcBow = 16.0;
    final results = <({Vector2 position, double angle})>[];

    for (int i = 0; i < cardCount; i++) {
      final t = cardCount == 1 ? 0.0 : (i / (cardCount - 1)) - 0.5;
      final angle = t * maxFanAngle;
      final arcOffset = (0.25 - t * t) * arcBow;
      final pos = Vector2(startX + i * cardSpacing, -arcOffset);
      results.add((position: pos, angle: angle));
    }
    return results;
  }

  static Vector2 _fanOffset(int relativeSeat) {
    return switch (relativeSeat) {
      1 => Vector2(50, 0),
      2 => Vector2(0, 40),
      3 => Vector2(-50, 0),
      _ => Vector2.zero(),
    };
  }

  static double _baseRotation(int relativeSeat) {
    return switch (relativeSeat) {
      1 => math.pi / 2,
      2 => math.pi,
      3 => -math.pi / 2,
      _ => 0.0,
    };
  }
}
