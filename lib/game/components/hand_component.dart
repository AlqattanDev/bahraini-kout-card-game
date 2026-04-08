import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/card.dart';
import '../../shared/models/game_state.dart';
import '../../shared/logic/card_utils.dart';
import '../../shared/logic/play_validator.dart';
import '../managers/layout_manager.dart';
import 'card_component.dart';

/// Displays the local player's hand as a fan of cards at the bottom.
///
/// Uses [LayoutManager.handCardPositions] to position cards in an arc.
/// Playable cards are highlighted; non-playable cards are greyed out.
class HandComponent extends Component {
  LayoutManager layout;
  final void Function(String cardCode) onCardTap;

  /// Scale factor applied to hand cards for readability.
  /// Dynamic: smaller on landscape phones, full 1.4x on portrait (default 1.4).
  double get handCardScale => layout.handCardScale;

  final List<CardComponent> _cards = [];

  /// Maps encoded card codes to their screen positions in the hand.
  /// [cardPositions] is the current frame, [previousCardPositions] preserves
  /// the last frame so that a just-played card's origin can still be looked up
  /// after the hand is rebuilt without it.
  final Map<String, Vector2> cardPositions = {};
  final Map<String, Vector2> previousCardPositions = {};

  HandComponent({required this.layout, required this.onCardTap});

  void updateState(ClientGameState state) {
    final hand = sortHandForDisplay(state.myHand, state.trumpSuit);
    final playable = _playableCards(state);
    final positions = layout.handCardPositions(hand.length);

    // Preserve previous positions so fly-to-trick animation knows the origin.
    previousCardPositions
      ..clear()
      ..addAll(cardPositions);
    cardPositions.clear();

    final hasPlayableCards = playable.isNotEmpty;
    final isWaitingForOthers =
        state.phase == GamePhase.playing && !state.isMyTurn;

    // Track cards we've kept so we can remove stale ones
    final Set<CardComponent> keptCards = {};

    for (int i = 0; i < hand.length; i++) {
      final gameCard = hand[i];
      final posData = positions[i];
      final highlight = playable.contains(gameCard);

      cardPositions[gameCard.encode()] = posData.position.clone();

      // Find if this card already exists in the hand
      CardComponent? existingCard;
      for (final c in _cards) {
        if (c.card?.encode() == gameCard.encode()) {
          existingCard = c;
          break;
        }
      }

      final isDimmed = isWaitingForOthers || (hasPlayableCards && !highlight);

      if (existingCard != null) {
        // Update properties and snap to position
        existingCard.isHighlighted = highlight;
        existingCard.isDimmed = isDimmed;
        existingCard.priority = i;
        existingCard.position.setFrom(posData.position);
        existingCard.angle = posData.angle;
        existingCard.scale = Vector2.all(handCardScale);
        existingCard.opacity = 1.0;

        keptCards.add(existingCard);
      } else {
        // Create new card at final position
        final cardComp = CardComponent(
          card: gameCard,
          isFaceUp: true,
          isHighlighted: highlight,
          isDimmed: isDimmed,
          showShadow: true,
          restScale: handCardScale,
          position: posData.position,
          angle: posData.angle,
          onTap: (c) => onCardTap(c.encode()),
        )
          ..scale = Vector2.all(handCardScale)
          ..priority = i;

        _cards.add(cardComp);
        add(cardComp);
        keptCards.add(cardComp);
      }
    }

    // Remove any cards that are no longer in hand
    final staleCards = _cards.where((c) => !keptCards.contains(c)).toList();
    for (final c in staleCards) {
      _cards.remove(c);
      c.removeFromParent();
    }
  }

  /// Determines which cards are playable in the current state.
  Set<GameCard> _playableCards(ClientGameState state) {
    if (!state.isMyTurn) return {};
    if (state.phase != GamePhase.playing) return {};

    final isLeadPlay = state.currentTrickPlays.isEmpty;
    final ledSuit = isLeadPlay ? null : state.currentTrickPlays.first.card.suit;

    return PlayValidator.playableForCurrentTrick(
      hand: state.myHand,
      trickHasNoPlaysYet: isLeadPlay,
      ledSuit: ledSuit,
      trumpSuit: state.trumpSuit,
      bidIsKout: state.currentBid?.isKout ?? false,
      noTricksCompletedYet: state.trickWinners.isEmpty,
    );
  }
}
