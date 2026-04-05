import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../managers/layout_manager.dart';
import '../theme/diwaniya_colors.dart';
import 'card_component.dart';

/// Displays the 0–4 cards currently played in the center trick area.
///
/// Cards are positioned by relative seat (0=bottom/me, 1=left, 2=top, 3=right).
/// Each card gets a base rotation per seat plus random jitter (±4.6°) for a
/// natural "tossed on table" feel.
class TrickAreaComponent extends Component {
  LayoutManager layout;
  final int mySeatIndex;
  final Random _random = Random();

  /// Horizontal nudge factor for stacking cards toward center.
  /// Each successive card drifts ~6% inward to make play order obvious.
  static const double _nudgeFactor = 0.06;

  final List<CardComponent> _trickCards = [];
  /// Cached jitter angles keyed by playerUid so cards don't wiggle on each update.
  final Map<String, double> _cachedJitter = {};

  TrickAreaComponent({
    required this.layout,
    required this.mySeatIndex,
  });

  @override
  void render(Canvas canvas) {
    // Subtle center marker on the table (thin gold ring, barely visible)
    final markerPaint = Paint()
      ..color = DiwaniyaColors.goldAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final base = layout.safeRect.width < layout.safeRect.height
        ? layout.safeRect.width
        : layout.safeRect.height;
    final radius = layout.isLandscape ? base * 0.10 : 60.0;
    canvas.drawCircle(
      Offset(layout.trickCenter.x, layout.trickCenter.y),
      radius,
      markerPaint,
    );
  }

  /// Rebuilds trick cards from [state.currentTrickPlays].
  void updateState(ClientGameState state) {
    for (final c in _trickCards) {
      c.removeFromParent();
    }
    _trickCards.clear();

    final activeUids = state.currentTrickPlays.map((p) => p.playerUid).toSet();
    _cachedJitter.removeWhere((uid, _) => !activeUids.contains(uid));

    for (int i = 0; i < state.currentTrickPlays.length; i++) {
      final play = state.currentTrickPlays[i];
      final absoluteSeat = state.playerUids.indexOf(play.playerUid);
      if (absoluteSeat < 0) continue;

      final relativeSeat = layout.toRelativeSeat(absoluteSeat, mySeatIndex);
      final basePos = layout.trickCardPosition(relativeSeat);
      final center = layout.trickCenter;
      final nudge = i * _nudgeFactor;
      final pos = basePos + (center - basePos) * nudge;

      final jitter = _cachedJitter.putIfAbsent(
        play.playerUid,
        () => (_random.nextDouble() - 0.5) * 0.10,
      );
      final angle = _seatBaseAngle(relativeSeat) + jitter;

      final trickScale = layout.trickCardScale;
      final cardComp = CardComponent(
        card: play.card,
        isFaceUp: true,
        isHighlighted: false,
        showShadow: true,
        restScale: trickScale,
        position: pos,
        angle: angle,
      )
        ..scale = Vector2.all(trickScale)
        ..priority = 10 + i;

      _trickCards.add(cardComp);
      add(cardComp);
    }
  }

  double _seatBaseAngle(int relativeSeat) {
    switch (relativeSeat) {
      case 1:
        return 0.10;
      case 2:
        return 0.05;
      case 3:
        return -0.10;
      default:
        return 0.0;
    }
  }

  void updateLayout(LayoutManager newLayout) {
    layout = newLayout;
  }
}
