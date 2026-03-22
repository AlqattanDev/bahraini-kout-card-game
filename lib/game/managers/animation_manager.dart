import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import '../components/card_component.dart';
import '../theme/kout_theme.dart';

/// Manages card animation sequences using Flame effects.
///
/// Provides:
/// - [animateCardPlay]: card arcs from hand/seat to trick area with drop shadow
/// - [animateTrickCollection]: all 4 trick cards slide to winning team's area
/// - [animateDeal]: cards fly from center to each seat with staggered delay
/// - [animatePoisonJoker]: card flashes red and shakes
/// - [animateTrickWin]: brief gold particle burst at the winning position
///
/// Audio hook points are provided as placeholder methods; no audio files are
/// required and they are no-ops by default.
class AnimationManager {
  final FlameGame game;

  AnimationManager({required this.game});

  // ---------------------------------------------------------------------------
  // Deal animation: staggered cards fly from center to seat positions
  // ---------------------------------------------------------------------------

  /// Animates dealing cards from the center to each player's seat.
  ///
  /// [playerCards] is a list of 4 lists (one per seat), each containing the
  /// CardComponents for that seat. [seatPositions] are the 4 seat center positions.
  Future<void> animateDeal(
    List<List<CardComponent>> playerCards,
    List<Vector2> seatPositions,
  ) async {
    onDealStart(); // audio hook

    final futures = <Future<void>>[];

    for (int seat = 0; seat < playerCards.length; seat++) {
      final cards = playerCards[seat];
      final target = seatPositions[seat];

      for (int i = 0; i < cards.length; i++) {
        final card = cards[i];
        final delay = (seat * cards.length + i) * 0.1; // 100ms stagger

        final future = Future<void>.delayed(
          Duration(milliseconds: (delay * 1000).round()),
          () => _moveCard(card, target, durationSeconds: 0.35),
        );
        futures.add(future);
      }
    }

    await Future.wait(futures);
    onDealComplete(); // audio hook
  }

  // ---------------------------------------------------------------------------
  // Play card animation: card arcs from source position to trick area
  // with a drop shadow that scales with travel distance
  // ---------------------------------------------------------------------------

  /// Animates a card flying from its current position to [target] in the trick
  /// area.
  ///
  /// Adds a [_CardShadowComponent] during movement: the shadow offset scales
  /// proportionally to the remaining distance, creating a sense of altitude.
  Future<void> animateCardPlay(CardComponent card, Vector2 target) async {
    onCardPlay(); // audio hook

    final moveCompleter = Completer<void>();
    final scaleCompleter = Completer<void>();

    // Attach a shadow component that fades out as the card lands
    final shadow = _CardShadowComponent(
      cardSize: card.size,
      totalDistance: card.position.distanceTo(target),
    );
    card.add(shadow);

    card.add(
      MoveEffect.to(
        target,
        CurvedEffectController(0.3, Curves.easeOut),
        onComplete: () {
          shadow.removeFromParent();
          moveCompleter.complete();
        },
      ),
    );

    card.add(
      ScaleEffect.to(
        Vector2.all(1.1),
        CurvedEffectController(0.15, Curves.easeOut),
        onComplete: () {
          card.add(
            ScaleEffect.to(
              Vector2.all(1.0),
              CurvedEffectController(0.15, Curves.easeIn),
              onComplete: scaleCompleter.complete,
            ),
          );
        },
      ),
    );

    await Future.wait([moveCompleter.future, scaleCompleter.future]);
  }

  // ---------------------------------------------------------------------------
  // Trick collection: 4 cards slide to winning team's area
  // ---------------------------------------------------------------------------

  /// Animates all trick cards sliding to [target] (the winning team's score area).
  ///
  /// All 4 cards animate simultaneously over 400ms.
  Future<void> animateTrickCollection(
    List<CardComponent> cards,
    Vector2 target,
  ) async {
    onTrickCollect(); // audio hook
    final futures = cards.map((card) => _moveCard(card, target, durationSeconds: 0.4)).toList();
    await Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Trick win celebration: gold particle burst
  // ---------------------------------------------------------------------------

  /// Spawns a brief gold particle burst at [position] to celebrate winning a trick.
  ///
  /// Emits [particleCount] small circles that expand outward and fade over [durationSeconds].
  void animateTrickWin(
    Vector2 position, {
    int particleCount = 12,
    double durationSeconds = 0.6,
  }) {
    onTrickWin(); // audio hook

    for (int i = 0; i < particleCount; i++) {
      final angle = (math.pi * 2 / particleCount) * i;
      final particle = _GoldParticleComponent(
        startPosition: position.clone(),
        angle: angle,
        durationSeconds: durationSeconds,
      );
      game.add(particle);
    }
  }

  // ---------------------------------------------------------------------------
  // Poison Joker: flash red and shake
  // ---------------------------------------------------------------------------

  /// Animates the poison joker: flashes red tint and shakes in place.
  Future<void> animatePoisonJoker(CardComponent card) async {
    onPoisonJoker(); // audio hook

    final originalPos = card.position.clone();

    // Shake: rapid left-right movement
    const shakeAmount = 6.0;
    const shakeDuration = 0.05;

    for (int i = 0; i < 6; i++) {
      final direction = i.isEven ? shakeAmount : -shakeAmount;
      final completer = Completer<void>();
      card.add(
        MoveEffect.to(
          Vector2(originalPos.x + direction, originalPos.y),
          LinearEffectController(shakeDuration),
          onComplete: completer.complete,
        ),
      );
      await completer.future;
    }

    // Return to original position
    final resetCompleter = Completer<void>();
    card.add(
      MoveEffect.to(
        originalPos,
        LinearEffectController(shakeDuration),
        onComplete: resetCompleter.complete,
      ),
    );
    await resetCompleter.future;
  }

  // ---------------------------------------------------------------------------
  // Audio hook points (placeholder — no audio files required)
  // ---------------------------------------------------------------------------

  /// Called when dealing begins. Hook point for deal sound.
  void onDealStart() {}

  /// Called when dealing completes. Hook point for shuffle-end sound.
  void onDealComplete() {}

  /// Called when a card is played. Hook point for card-slap sound.
  void onCardPlay() {}

  /// Called when a trick is won. Hook point for trick-win chime.
  void onTrickWin() {}

  /// Called when trick cards are collected. Hook point for card-sweep sound.
  void onTrickCollect() {}

  /// Called when the poison joker is played. Hook point for joker sound.
  void onPoisonJoker() {}

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _moveCard(
    CardComponent card,
    Vector2 target, {
    required double durationSeconds,
  }) async {
    final completer = Completer<void>();
    card.add(
      MoveEffect.to(
        target,
        CurvedEffectController(durationSeconds, Curves.easeOut),
        onComplete: completer.complete,
      ),
    );
    return completer.future;
  }
}

// ---------------------------------------------------------------------------
// Drop shadow component
// ---------------------------------------------------------------------------

/// Renders a drop shadow beneath a card while it is in motion.
///
/// The shadow offset scales with [totalDistance]: at the start of flight the
/// shadow is largest (highest altitude), and it shrinks to zero as the card
/// lands.
class _CardShadowComponent extends PositionComponent {
  final Vector2 cardSize;
  final double totalDistance;
  double _elapsed = 0;
  static const double _flightDuration = 0.3; // matches MoveEffect duration

  _CardShadowComponent({
    required this.cardSize,
    required this.totalDistance,
  }) : super(position: Vector2.zero(), anchor: Anchor.topLeft);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed = (_elapsed + dt).clamp(0.0, _flightDuration);
  }

  @override
  void render(Canvas canvas) {
    final progress = _elapsed / _flightDuration; // 0.0 = start, 1.0 = landed
    final altitude = 1.0 - progress; // 1.0 = high, 0.0 = landed
    final maxOffset = math.min(totalDistance * 0.12, 14.0);
    final shadowOffset = maxOffset * altitude;

    if (shadowOffset < 0.5) return; // not worth drawing

    final shadowRect = Rect.fromLTWH(
      shadowOffset,
      shadowOffset,
      cardSize.x,
      cardSize.y,
    );
    final shadowPaint = Paint()
      ..color = const Color(0x55000000).withOpacity(0.35 * altitude)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowOffset * 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(6)),
      shadowPaint,
    );
  }
}

// ---------------------------------------------------------------------------
// Gold particle component (trick win celebration)
// ---------------------------------------------------------------------------

/// A single expanding gold circle particle for the trick-win celebration.
class _GoldParticleComponent extends PositionComponent {
  final double angle;
  final double durationSeconds;
  double _elapsed = 0;

  static const double _speed = 80.0; // pixels per second
  static const double _maxRadius = 5.0;

  _GoldParticleComponent({
    required Vector2 startPosition,
    required this.angle,
    required this.durationSeconds,
  }) : super(position: startPosition, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    // Move outward
    position.x += math.cos(angle) * _speed * dt;
    position.y += math.sin(angle) * _speed * dt;

    if (_elapsed >= durationSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / durationSeconds).clamp(0.0, 1.0);
    final opacity = 1.0 - progress; // fade out
    final radius = _maxRadius * (0.3 + progress * 0.7); // grow slightly

    final paint = Paint()
      ..color = KoutTheme.accent.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}
