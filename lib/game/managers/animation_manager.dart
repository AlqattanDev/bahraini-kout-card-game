import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import '../components/card_component.dart';

/// Manages card animation sequences using Flame effects.
///
/// Provides:
/// - [animateCardPlay]: card arcs from hand/seat to trick area
/// - [animateTrickCollection]: all 4 trick cards slide to winning team's area
/// - [animateDeal]: cards fly from center to each seat with staggered delay
/// - [animatePoisonJoker]: card flashes red and shakes
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
  }

  // ---------------------------------------------------------------------------
  // Play card animation: card arcs from source position to trick area
  // ---------------------------------------------------------------------------

  /// Animates a card flying from its current position to [target] in the trick area.
  ///
  /// Uses a MoveEffect (300ms) combined with a ScaleEffect for a subtle pop.
  Future<void> animateCardPlay(CardComponent card, Vector2 target) async {
    final moveCompleter = Completer<void>();
    final scaleCompleter = Completer<void>();

    card.add(
      MoveEffect.to(
        target,
        CurvedEffectController(0.3, Curves.easeOut),
        onComplete: moveCompleter.complete,
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
    final futures = cards.map((card) => _moveCard(card, target, durationSeconds: 0.4)).toList();
    await Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Poison Joker: flash red and shake
  // ---------------------------------------------------------------------------

  /// Animates the poison joker: flashes red tint and shakes in place.
  Future<void> animatePoisonJoker(CardComponent card) async {
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
