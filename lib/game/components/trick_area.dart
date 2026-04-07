import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
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

  /// Inward nudge per successive card — keeps play order visible.
  static const double _nudgeFactor = 0.04;

  final List<CardComponent> _trickCards = [];
  /// Cached jitter angles keyed by playerUid so cards don't wiggle on each update.
  final Map<String, double> _cachedJitter = {};
  
  double _time = 0.0;

  TrickAreaComponent({
    required this.layout,
    required this.mySeatIndex,
  });

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    // Subtle center marker on the table (thin gold ring, barely visible)
    // Sine pulse 0.15-0.25 over 2s. Period = 2s -> frequency = 1/2 Hz -> angular freq = pi rad/s.
    // sin(pi * t) oscillates -1 to 1.
    // Normalized to 0-1: (sin(pi * t) + 1) / 2
    // Range 0.15 to 0.25 -> 0.15 + (normalized * 0.10)
    // Or simpler: base 0.20 + 0.05 * sin(pi * t)
    final double pulseAlpha = 0.20 + 0.05 * sin(pi * _time);

    final markerPaint = Paint()
      ..color = DiwaniyaColors.goldAccent.withValues(alpha: pulseAlpha)
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
    final activeUids = state.currentTrickPlays.map((p) => p.playerUid).toSet();
    _cachedJitter.removeWhere((uid, _) => !activeUids.contains(uid));

    // Track cards to keep
    final Set<CardComponent> keptCards = {};

    for (int i = 0; i < state.currentTrickPlays.length; i++) {
      final play = state.currentTrickPlays[i];
      final absoluteSeat = state.playerUids.indexOf(play.playerUid);
      if (absoluteSeat < 0) continue;

      final relativeSeat = layout.toRelativeSeat(absoluteSeat, mySeatIndex);
      final basePos = layout.trickCardPosition(relativeSeat);
      final center = layout.trickCenter;
      final nudge = i * _nudgeFactor;
      final targetPos = basePos + (center - basePos) * nudge;

      final jitter = _cachedJitter.putIfAbsent(
        play.playerUid,
        () => (_random.nextDouble() - 0.5) * 0.10,
      );
      final angle = _seatBaseAngle(relativeSeat) + jitter;

      final trickScale = layout.trickCardScale;

      // Find if this card is already displayed
      CardComponent? existingCard;
      for (final c in _trickCards) {
        if (c.card?.encode() == play.card.encode()) {
          existingCard = c;
          break;
        }
      }

      if (existingCard != null) {
        existingCard.priority = 10 + i;
        // The card is already here, we don't need to fly it in, but we can reposition it just in case
        existingCard.add(MoveEffect.to(
          targetPos,
          EffectController(duration: 0.2),
        ));
        keptCards.add(existingCard);
      } else {
        // New trick card. Check if there's an existing card flying in from AnimationManager
        // If not, we'll add a fly-in effect from the base position of the seat (or screen edge).
        final cardComp = CardComponent(
          card: play.card,
          isFaceUp: true,
          isHighlighted: false,
          showShadow: true,
          restScale: trickScale,
          position: targetPos,
          angle: angle,
        )
          ..scale = Vector2.all(trickScale)
          ..priority = 10 + i;

        // Fly-in from seat direction
        final startPos = targetPos + (basePos - center).normalized() * 50;
        cardComp.position = startPos;
        cardComp.add(MoveEffect.to(
          targetPos,
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ));

        _trickCards.add(cardComp);
        add(cardComp);
        keptCards.add(cardComp);
      }
    }

    // Remove cards no longer in trick
    final staleCards = _trickCards.where((c) => !keptCards.contains(c)).toList();
    for (final c in staleCards) {
      c.removeFromParent();
      _trickCards.remove(c);
    }
  }

  double _seatBaseAngle(int relativeSeat) {
    switch (relativeSeat) {
      case 1:
        return 0.18;   // left player → rotated clockwise
      case 2:
        return 0.10;   // partner → subtle tilt (not upside-down)
      case 3:
        return -0.18;  // right player → rotated counter-clockwise
      default:
        return 0.0;    // me → upright
    }
  }

  void updateLayout(LayoutManager newLayout) {
    layout = newLayout;
  }
}
