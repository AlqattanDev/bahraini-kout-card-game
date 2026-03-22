import 'package:flame/components.dart';
import '../../app/models/client_game_state.dart';
import '../../shared/models/card.dart';
import '../managers/layout_manager.dart';
import '../theme/kout_theme.dart';
import 'card_component.dart';

/// Displays the local player's hand as a fan of cards at the bottom.
///
/// Uses [LayoutManager.handCardPositions] to position cards in an arc.
/// Playable cards are highlighted; non-playable cards are greyed out.
class HandComponent extends Component {
  final LayoutManager layout;
  final void Function(String cardCode) onCardTap;

  final List<CardComponent> _cards = [];

  HandComponent({required this.layout, required this.onCardTap});

  /// Rebuilds hand cards based on updated game state.
  void updateState(ClientGameState state) {
    // Remove existing card children
    for (final c in _cards) {
      c.removeFromParent();
    }
    _cards.clear();

    final hand = state.myHand;
    if (hand.isEmpty) return;

    final playable = _playableCards(state);
    final positions = layout.handCardPositions(hand.length);

    for (int i = 0; i < hand.length; i++) {
      final gameCard = hand[i];
      final posData = positions[i];
      final highlight = playable.contains(gameCard);

      final cardComp = CardComponent(
        card: gameCard,
        isFaceUp: true,
        isHighlighted: highlight,
        position: posData.position,
        angle: posData.angle,
        onTap: (c) => onCardTap(c.encode()),
      );

      _cards.add(cardComp);
      add(cardComp);
    }
  }

  /// Determines which cards are playable in the current state.
  Set<GameCard> _playableCards(ClientGameState state) {
    if (!state.isMyTurn) return {};
    if (state.phase.name != 'playing') return {};

    // If a suit was led, player must follow suit if possible
    if (state.currentTrickPlays.isEmpty) {
      // Leading — all cards are playable
      return state.myHand.toSet();
    }

    final ledSuit = state.currentTrickPlays.first.card.suit;
    if (ledSuit == null) return state.myHand.toSet(); // joker led

    final followSuitCards =
        state.myHand.where((c) => c.suit == ledSuit).toSet();
    if (followSuitCards.isNotEmpty) return followSuitCards;

    // Can't follow suit — any card is playable
    return state.myHand.toSet();
  }
}
